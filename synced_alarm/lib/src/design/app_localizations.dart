import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      'app_title': 'Synced Alarm',
      'alarms': 'Alarms',
      'history': 'History',
      'settings': 'Settings',
      'new_alarm': 'New alarm',
      'edit_alarm': 'Edit alarm',
      'delete_alarm': 'Delete alarm',
      'delete_confirm': 'Delete alarm?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'save': 'Save',
      'label': 'Label',
      'time': 'Time',
      'repeat': 'Repeat',
      'sound': 'Sound',
      'vibration': 'Vibration',
      'snooze': 'Snooze',
      'dismiss': 'Dismiss',
      'sync_status': 'Sync status',
      'no_alarms': 'No alarms yet',
      'no_history': 'No alarm history',
      'sign_in': 'Sign in',
      'sign_out': 'Sign out',
      'account': 'Account',
      'group': 'Group',
      'create_group': 'Create group',
      'join_group': 'Join group',
      'group_name': 'Group name',
      'group_id': 'Group ID',
      'invite_code': 'Invite code',
      'rings_in': 'Rings in',
      'starts_in': 'Starts in',
      'next_alarm': 'Next Alarm',
      'test_ring': 'Test ring',
      'sync_unavailable': 'Sync unavailable',
      'retry': 'Retry',
      'rings_now': 'Rings now',
      'off': 'Off',
      'sync_account': 'SYNC & ACCOUNT',
      'cloud_sync': 'Cloud Synchronization',
      'local_demo': 'Local demo',
      'active': 'Active',
      'needs_group': 'Needs group',
      'local_mode': 'Local mode',
      'shared_group': 'Shared group',
      'no_group': 'No group',
      'local_only': 'Local only',
      'group_mgmt': 'Group management',
      'alarm_defaults': 'ALARM DEFAULTS',
      'snooze_duration': 'Snooze Duration',
      'notification_scope': 'Notification scope',
      'appearance': 'APPEARANCE',
      'design_ref': 'Design reference',
      'wake_up': 'Wake up',
      'set_alarm': 'Set alarm',
      'save_alarm': 'Save alarm',
      'snooze_after': 'Snooze after',
      'max_snoozes': 'Max snoozes',
      'times': 'times',
      'min': 'min',
      'ring_duration': 'Ring duration',
      'mon': 'M',
      'tue': 'T',
      'wed': 'W',
      'thu': 'T',
      'fri': 'F',
      'sat': 'S',
      'sun': 'S',
      'create_account': 'Create account',
      'name': 'Name',
      'email': 'Email',
      'password': 'Password',
      'use_existing_account': 'Use an existing account',
      'create_new_account': 'Create a new account',
      'error_enter_email_password':
          'Enter an email and a 6+ character password.',
      'error_enter_name': 'Enter a name for this account.',
      'alarm_group': 'Alarm Group',
      'create': 'Create',
      'join': 'Join',
      'your_groups': 'Your groups',
      'error_invite_code_length':
          'Enter an invite code with at least 4 characters.',
      'error_group_id_required': 'Group ID is required.',
      'error_group_name_required': 'Group name is required.',
      'alarm': 'Alarm',
      'error_could_not_save_alarm': 'Could not save alarm',
      'alarm_actions': 'Alarm actions',
      'error_alarm_action_failed': 'Alarm action failed',
      'firebase_mode_disabled': 'Firebase mode is not enabled for this run.',
      'sign_in_to_sync': 'Sign in to sync alarms with a group.',
      'need_group_to_sync': 'Create or join a group before syncing alarms.',
      'create_join_switch': 'Create, join, or switch',
      'open': 'Open',
      'local_alarms': 'Local alarms',
      'no_account_required': 'No account required',
    },
    'ko': {
      'app_title': '동기화 알람',
      'alarms': '알람',
      'history': '기록',
      'settings': '설정',
      'new_alarm': '새 알람',
      'edit_alarm': '알람 수정',
      'delete_alarm': '알람 삭제',
      'delete_confirm': '알람을 삭제할까요?',
      'cancel': '취소',
      'delete': '삭제',
      'save': '저장',
      'label': '이름',
      'time': '시간',
      'repeat': '반복',
      'sound': '소리',
      'vibration': '진동',
      'snooze': '다시 알림',
      'dismiss': '해제',
      'sync_status': '동기화 상태',
      'no_alarms': '설정된 알람이 없습니다',
      'no_history': '알람 기록이 없습니다',
      'sign_in': '로그인',
      'sign_out': '로그아웃',
      'account': '계정',
      'group': '그룹',
      'create_group': '그룹 생성',
      'join_group': '그룹 참가',
      'group_name': '그룹 이름',
      'group_id': '그룹 ID',
      'invite_code': '초대 코드',
      'rings_in': '알람까지',
      'starts_in': '시작까지',
      'next_alarm': '다음 알람',
      'test_ring': '테스트 울림',
      'sync_unavailable': '동기화 불가',
      'retry': '재시도',
      'rings_now': '지금 울림',
      'off': '꺼짐',
      'sync_account': '동기화 및 계정',
      'cloud_sync': '클라우드 동기화',
      'local_demo': '로컬 데모',
      'active': '활성',
      'needs_group': '그룹 필요',
      'local_mode': '로컬 모드',
      'shared_group': '공유 그룹',
      'no_group': '그룹 없음',
      'local_only': '로컬 전용',
      'group_mgmt': '그룹 관리',
      'alarm_defaults': '알람 기본 설정',
      'snooze_duration': '다시 알림 간격',
      'notification_scope': '알림 범위',
      'appearance': '디자인',
      'design_ref': '디자인 레퍼런스',
      'wake_up': '기상',
      'set_alarm': '알람 설정',
      'save_alarm': '알람 저장',
      'snooze_after': '다시 알림 간격',
      'max_snoozes': '최대 다시 알림 횟수',
      'times': '회',
      'min': '분',
      'ring_duration': '알람 울림 시간',
      'mon': '월',
      'tue': '화',
      'wed': '수',
      'thu': '목',
      'fri': '금',
      'sat': '토',
      'sun': '일',
      'create_account': '계정 만들기',
      'name': '이름',
      'email': '이메일',
      'password': '비밀번호',
      'use_existing_account': '기존 계정 사용',
      'create_new_account': '새 계정 만들기',
      'error_enter_email_password': '이메일과 6자 이상의 비밀번호를 입력해주세요.',
      'error_enter_name': '이름을 입력해주세요.',
      'alarm_group': '알람 그룹',
      'create': '생성',
      'join': '참가',
      'your_groups': '내 그룹',
      'error_invite_code_length': '4자 이상의 초대 코드를 입력해주세요.',
      'error_group_id_required': '그룹 ID가 필요합니다.',
      'error_group_name_required': '그룹 이름이 필요합니다.',
      'alarm': '알람',
      'error_could_not_save_alarm': '알람을 저장할 수 없습니다',
      'alarm_actions': '알람 작업',
      'error_alarm_action_failed': '알람 작업을 실패했습니다',
      'firebase_mode_disabled': '이번 실행에서는 Firebase 모드가 활성화되지 않았습니다.',
      'sign_in_to_sync': '알람을 그룹과 동기화하려면 로그인하세요.',
      'need_group_to_sync': '알람을 동기화하려면 그룹을 생성하거나 참가하세요.',
      'create_join_switch': '생성, 참가 또는 전환',
      'open': '열기',
      'local_alarms': '로컬 알람',
      'no_account_required': '계정 필요 없음',
    },
  };

  String get appTitle => _getValue('app_title');
  String get alarms => _getValue('alarms');
  String get history => _getValue('history');
  String get settings => _getValue('settings');
  String get newAlarm => _getValue('new_alarm');
  String get editAlarm => _getValue('edit_alarm');
  String get deleteAlarm => _getValue('delete_alarm');
  String get deleteConfirm => _getValue('delete_confirm');
  String get cancel => _getValue('cancel');
  String get delete => _getValue('delete');
  String get save => _getValue('save');
  String get label => _getValue('label');
  String get time => _getValue('time');
  String get repeat => _getValue('repeat');
  String get sound => _getValue('sound');
  String get vibration => _getValue('vibration');
  String get snooze => _getValue('snooze');
  String get dismiss => _getValue('dismiss');
  String get syncStatus => _getValue('sync_status');
  String get noAlarms => _getValue('no_alarms');
  String get noHistory => _getValue('no_history');
  String get signIn => _getValue('sign_in');
  String get signOut => _getValue('sign_out');
  String get account => _getValue('account');
  String get group => _getValue('group');
  String get createGroup => _getValue('create_group');
  String get joinGroup => _getValue('join_group');
  String get groupName => _getValue('group_name');
  String get groupId => _getValue('group_id');
  String get inviteCode => _getValue('invite_code');
  String get nextAlarm => _getValue('next_alarm');
  String get testRing => _getValue('test_ring');
  String get syncUnavailable => _getValue('sync_unavailable');
  String get retry => _getValue('retry');
  String get ringsNow => _getValue('rings_now');
  String get off => _getValue('off');
  String get syncAccount => _getValue('sync_account');
  String get cloudSync => _getValue('cloud_sync');
  String get localDemo => _getValue('local_demo');
  String get active => _getValue('active');
  String get needsGroup => _getValue('needs_group');
  String get localMode => _getValue('local_mode');
  String get sharedGroup => _getValue('shared_group');
  String get noGroup => _getValue('no_group');
  String get localOnly => _getValue('local_only');
  String get groupMgmt => _getValue('group_mgmt');
  String get alarmDefaults => _getValue('alarm_defaults');
  String get snoozeDuration => _getValue('snooze_duration');
  String get notificationScope => _getValue('notification_scope');
  String get appearance => _getValue('appearance');
  String get designRef => _getValue('design_ref');
  String get wakeUp => _getValue('wake_up');
  String get setAlarm => _getValue('set_alarm');
  String get saveAlarm => _getValue('save_alarm');
  String get snoozeAfter => _getValue('snooze_after');
  String get maxSnoozes => _getValue('max_snoozes');
  String get times => _getValue('times');
  String get min => _getValue('min');
  String get ringDuration => _getValue('ring_duration');
  String get createAccount => _getValue('create_account');
  String get name => _getValue('name');
  String get email => _getValue('email');
  String get password => _getValue('password');
  String get useExistingAccount => _getValue('use_existing_account');
  String get createNewAccount => _getValue('create_new_account');
  String get errorEnterEmailPassword => _getValue('error_enter_email_password');
  String get errorEnterName => _getValue('error_enter_name');
  String get alarmGroup => _getValue('alarm_group');
  String get create => _getValue('create');
  String get join => _getValue('join');
  String get yourGroups => _getValue('your_groups');
  String get errorInviteCodeLength => _getValue('error_invite_code_length');
  String get errorGroupIdRequired => _getValue('error_group_id_required');
  String get errorGroupNameRequired => _getValue('error_group_name_required');
  String get alarm => _getValue('alarm');
  String get errorCouldNotSaveAlarm => _getValue('error_could_not_save_alarm');
  String get alarmActions => _getValue('alarm_actions');
  String get errorAlarmActionFailed => _getValue('error_alarm_action_failed');
  String get firebaseModeDisabled => _getValue('firebase_mode_disabled');
  String get signInToSync => _getValue('sign_in_to_sync');
  String get needGroupToSync => _getValue('need_group_to_sync');
  String get createJoinSwitch => _getValue('create_join_switch');
  String get open => _getValue('open');
  String get localAlarms => _getValue('local_alarms');
  String get noAccountRequired => _getValue('no_account_required');

  String get mon => _getValue('mon');
  String get tue => _getValue('tue');
  String get wed => _getValue('wed');
  String get thu => _getValue('thu');
  String get fri => _getValue('fri');
  String get sat => _getValue('sat');
  String get sun => _getValue('sun');

  String ringsIn(String duration) => '${_getValue('rings_in')} $duration';
  String startsIn(String duration) => '${_getValue('starts_in')} $duration';

  String _getValue(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key]!;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ko'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return Future.value(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
