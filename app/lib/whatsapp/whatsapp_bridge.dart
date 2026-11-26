import 'dart:io';

import 'package:flutter/services.dart';

import 'pack_models.dart';
import 'pack_store.dart';

/// Which WhatsApp apps are on the phone, and whether a pack is in each.
class WhatsAppStatus {
  const WhatsAppStatus({
    required this.consumerInstalled,
    required this.businessInstalled,
    this.consumerHasPack,
    this.businessHasPack,
  });

  factory WhatsAppStatus.fromMap(Map<Object?, Object?> map) => WhatsAppStatus(
    consumerInstalled: map['consumerInstalled'] == true,
    businessInstalled: map['businessInstalled'] == true,
    consumerHasPack: map['consumerHasPack'] as bool?,
    businessHasPack: map['businessHasPack'] as bool?,
  );

  final bool consumerInstalled;
  final bool businessInstalled;

  /// Null when unknown (app missing, or iOS, which can't tell us).
  final bool? consumerHasPack;
  final bool? businessHasPack;

  bool get anyInstalled => consumerInstalled || businessInstalled;
}

enum AddPackOutcome {
  /// Android: WhatsApp confirmed the pack was added.
  added,

  /// iOS: handed over; WhatsApp shows its own preview and never reports back.
  sentToWhatsApp,

  /// The user backed out of WhatsApp's dialog.
  cancelled,

  /// WhatsApp refused the pack; [AddPackResult.message] says why.
  rejected,

  notInstalled,

  /// We caught a problem before sending; see [AddPackResult.problems].
  invalid,
}

class AddPackResult {
  const AddPackResult(this.outcome, {this.message, this.problems = const []});

  final AddPackOutcome outcome;
  final String? message;
  final List<PackProblem> problems;

  @override
  String toString() =>
      '${outcome.name}${message == null ? '' : ': $message'}'
      '${problems.isEmpty ? '' : ' $problems'}';
}

/// Talks to the native WhatsApp bridge (MainActivity.kt / AppDelegate.swift).
class WhatsAppBridge {
  WhatsAppBridge({MethodChannel? channel, bool? isIOS})
    : _channel = channel ?? const MethodChannel('peel/whatsapp'),
      _isIOS = isIOS ?? Platform.isIOS;

  final MethodChannel _channel;
  final bool _isIOS;

  Future<WhatsAppStatus> status({String? identifier}) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('status', {
      'identifier': identifier,
    });
    return WhatsAppStatus.fromMap(map ?? const {});
  }

  /// Opens WhatsApp (or WhatsApp Business). False if neither is installed.
  Future<bool> open() async =>
      (await _channel.invokeMethod<bool>('openWhatsApp')) ?? false;

  /// Validates [pack], then asks WhatsApp to add (or refresh) it.
  Future<AddPackResult> addPack(PackStore store, PackEntry pack) async {
    final problems = await store.validate(pack);
    if (problems.isNotEmpty) {
      return AddPackResult(AddPackOutcome.invalid, problems: problems);
    }

    final Map<Object?, Object?>? reply;
    if (_isIOS) {
      reply = await _channel.invokeMapMethod('sendPack', {
        'payload': await store.iosPayload(pack),
      });
    } else {
      reply = await _channel.invokeMapMethod('addPack', {
        'identifier': pack.identifier,
        'name': pack.name,
      });
    }
    return _parse(reply);
  }

  static AddPackResult _parse(Map<Object?, Object?>? reply) {
    final outcome = AddPackOutcome.values.firstWhere(
      (o) => o.name == reply?['outcome'],
      orElse: () => AddPackOutcome.rejected,
    );
    return AddPackResult(outcome, message: reply?['message'] as String?);
  }
}
