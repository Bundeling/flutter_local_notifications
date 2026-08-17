import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();

  const EventChannel backgroundChannel = EventChannel(
    'dexterous.com/flutter/local_notifications/actions',
  );

  const MethodChannel channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  channel.invokeMethod<int>('getCallbackHandle').then((int? handle) {
    final DidReceiveBackgroundNotificationResponseCallback? callback =
        handle == null
        ? null
        : PluginUtilities.getCallbackFromHandle(
                CallbackHandle.fromRawHandle(handle),
              )
              as DidReceiveBackgroundNotificationResponseCallback?;

    backgroundChannel
        .receiveBroadcastStream()
        .map<Map<dynamic, dynamic>>((dynamic event) => event)
        .map<Map<String, dynamic>>(
          (Map<dynamic, dynamic> event) => Map.castFrom(event),
        )
        .listen((Map<String, dynamic> event) async {
          final Object notificationId = event['notificationId'];
          final int id;
          if (notificationId is int) {
            id = notificationId;
          } else if (notificationId is String) {
            id = int.parse(notificationId);
          } else {
            id = -1;
          }
          try {
            // A plain action tap doesn't include a response type, so default to
            // it when none is provided.
            final Object? responseTypeIndex = event['notificationResponseType'];
            final NotificationResponseType notificationResponseType =
                responseTypeIndex is int
                ? NotificationResponseType.values[responseTypeIndex]
                : NotificationResponseType.selectedNotificationAction;
            final dynamic handled = (callback as Function?)?.call(
              NotificationResponse(
                id: id,
                actionId: event['actionId'],
                input: event['input'],
                payload: event['payload'],
                notificationResponseType: notificationResponseType,
              ),
            );
            if (handled is Future) {
              await handled;
            }
          } finally {
            try {
              // Ends the iOS background task keeping the process alive.
              await channel.invokeMethod<void>('backgroundActionHandled');
            } on MissingPluginException {
              // Other platforms don't implement the acknowledgement.
            }
          }
        });
  });
}
