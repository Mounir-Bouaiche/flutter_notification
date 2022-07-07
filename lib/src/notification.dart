import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:notifications/notification.dart';

class NotificationIdProvider {
  int id;

  NotificationIdProvider([int initial = -1]) : id = initial;

  int get next => ++id;

  int get current => id;
}

typedef AwesomeNotificationListener = void Function(
  ReceivedNotification notification,
);

typedef AwesomeNotificationSchedule = NotificationSchedule Function(
  String timezone,
);

typedef NotificationPayload = Map<String, String>;

class NotificationService {
  final _payload = BehaviorSubject<NotificationPayload?>()..add(null);

  NotificationService._() : _awesome = AwesomeNotifications() {
    WidgetsFlutterBinding.ensureInitialized();
    _subscription = _awesome.actionStream.listen((notification) {
      _payload.add(notification.payload);
    });
  }

  late StreamSubscription<NotificationPayload?> Function(
    void Function(NotificationPayload? payload)? onData, {
    bool? cancelOnError,
    void Function()? onDone,
    Function? onError,
  }) onTap = _payload.listen;

  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  final AwesomeNotifications _awesome;

  late final StreamSubscription _subscription;
  late final NotificationIdProvider _idProvider;

  late NotificationChannel _channel;
  late NotificationChannelGroup _channelGroup;
  late String _localTimeZone;

  Future<bool> init({
    required String channelKey,
    required String channelGroupKey,
    required String channelGroupName,
    String? defaultIcon,
    String? channelName,
    String? channelDescription,
    Color? defaultColor,
    Color? ledColor,
    bool debug = kDebugMode,
    NotificationIdProvider? idProvider,
  }) async {
    final channelPlaceholder = channelKey.split('_').join(' ');
    channelName ??= channelPlaceholder;
    channelDescription ??= channelPlaceholder;

    _channel = NotificationChannel(
      channelKey: channelKey,
      channelGroupKey: channelGroupKey,
      channelName: channelName,
      channelDescription: channelDescription,
      defaultColor: defaultColor,
      ledColor: ledColor,
    );

    _channelGroup = NotificationChannelGroup(
      channelGroupkey: channelGroupKey,
      channelGroupName: channelGroupName,
    );

    _localTimeZone = await _awesome.getLocalTimeZoneIdentifier();

    _idProvider = idProvider ?? NotificationIdProvider();

    return _awesome.initialize(
      defaultIcon,
      [_channel],
      channelGroups: [_channelGroup],
      debug: debug,
    );
  }

  Future<bool> createNotification({
    int? id,
    String? title,
    String? body,
    bool? autoDismissible,
    Color? backgroundColor,
    NotificationLayout? notificationLayout,
    Map<String, String>? payload,
    bool wakeUpScreen = true,
    AwesomeNotificationSchedule? schedule,
    DateTime? scheduleDate,
    List<NotificationActionButton>? actionButtons,
  }) {
    return create(
      content: NotificationContent(
        id: id ?? nextId,
        channelKey: _channel.channelKey!,
        title: title,
        body: body,
        autoDismissible: autoDismissible,
        backgroundColor: backgroundColor,
        payload: payload,
        wakeUpScreen: wakeUpScreen,
        notificationLayout: notificationLayout,
      ),
      schedule: schedule?.call(_localTimeZone) ??
          (scheduleDate == null ? null : NotificationCalendar.fromDate(date: scheduleDate)),
      actionButtons: actionButtons,
    );
  }

  Future<bool> show(
    NotificationContent content, {
    NotificationSchedule Function(String timezone)? schedule,
    List<NotificationActionButton>? actionButtons,
  }) {
    return create(
      content: content,
      schedule: schedule?.call(_localTimeZone),
      actionButtons: actionButtons,
    );
  }

  Future<void> cancel({
    int? id,
    bool onlyScheduled = false,
  }) {
    if (onlyScheduled) {
      if (id != null) {
        return _awesome.cancelSchedule(id);
      } else {
        return _awesome.cancelAllSchedules();
      }
    } else {
      if (id != null) {
        return _awesome.cancel(id);
      } else {
        return _awesome.cancelAll();
      }
    }
  }

  // Helpers
  int get nextId => _idProvider.next;
  int get currentId => _idProvider.current;

  late Future<bool> Function({
    required NotificationContent content,
    NotificationSchedule? schedule,
    List<NotificationActionButton>? actionButtons,
  }) create = _awesome.createNotification;

  String? get channelKey => _channel.channelKey;

  Future<List<NotificationPermission>> requestUserPermissions<T>({
    FutureOr<T> Function(FutureOr Function() request)? builder,
    List<NotificationPermission> permissionList = const [
      NotificationPermission.Alert,
      NotificationPermission.Sound,
    ],
  }) async {
    // Check if the basic permission was conceived by the user
    /*if(!await requestBasicPermissionToSendNotifications(context))
      return [];*/

    // Check which of the permissions you need are allowed at this time
    List<NotificationPermission> permissionsAllowed = await AwesomeNotifications().checkPermissionList(
      channelKey: channelKey,
      permissions: permissionList,
    );

    // If all permissions are allowed, there is nothing to do
    if (permissionsAllowed.length == permissionList.length) {
      return permissionsAllowed;
    }

    // Refresh the permission list with only the disallowed permissions
    List<NotificationPermission> permissionsNeeded =
        permissionList.toSet().difference(permissionsAllowed.toSet()).toList();

    // Check if some of the permissions needed request user's intervention to be enabled
    List<NotificationPermission> lockedPermissions = await AwesomeNotifications().shouldShowRationaleToRequest(
      channelKey: channelKey,
      permissions: permissionsNeeded,
    );

    // If there is no permissions depending on user's intervention, so request it directly
    if (lockedPermissions.isEmpty) {
      // Request the permission through native resources.
      await AwesomeNotifications().requestPermissionToSendNotifications(
        channelKey: channelKey,
        permissions: permissionsNeeded,
      );

      // After the user come back, check if the permissions has successfully enabled
      permissionsAllowed = await AwesomeNotifications().checkPermissionList(
        channelKey: channelKey,
        permissions: permissionsNeeded,
      );
    } else {
      // If you need to show a rationale to educate the user to conceived the permission, show it
      await builder?.call(
        () async {
          // Request the permission through native resources. Only one page redirection is done at this point.
          await AwesomeNotifications().requestPermissionToSendNotifications(
            channelKey: channelKey,
            permissions: lockedPermissions,
          );

          // After the user come back, check if the permissions has successfully enabled
          permissionsAllowed = await AwesomeNotifications().checkPermissionList(
            channelKey: channelKey,
            permissions: lockedPermissions,
          );
        },
      );
    }

    // Return the updated list of allowed permissions
    return permissionsAllowed;
  }

  @mustCallSuper
  void close() {
    _subscription.cancel();
    _instance = null;
  }
}
