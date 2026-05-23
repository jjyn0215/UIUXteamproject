import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../design/app_localizations.dart';
import '../../design/app_theme.dart';
import '../../models/account.dart';

class GroupSetupScreen extends ConsumerStatefulWidget {
  const GroupSetupScreen({super.key});

  @override
  ConsumerState<GroupSetupScreen> createState() => _GroupSetupScreenState();
}

class _GroupSetupScreenState extends ConsumerState<GroupSetupScreen> {
  final _nameController = TextEditingController(text: 'Family alarms');
  final _groupIdController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _joining = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _groupIdController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(userGroupsProvider).value ?? const [];
    final title = _joining ? l10n.joinGroup : l10n.createGroup;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.alarmGroup),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _busy
                ? null
                : () => ref.read(accountRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.margin),
            shrinkWrap: true,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (groups.isNotEmpty) ...[
                        _ExistingGroupsCard(groups: groups, busy: _busy),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              SegmentedButton<bool>(
                                segments: [
                                  ButtonSegment(
                                    value: false,
                                    icon: const Icon(Icons.add_rounded),
                                    label: Text(l10n.create),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    icon: const Icon(Icons.group_add_outlined),
                                    label: Text(l10n.join),
                                  ),
                                ],
                                selected: {_joining},
                                onSelectionChanged: _busy
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          _joining = selected.first;
                                          _error = null;
                                        });
                                      },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (_joining) ...[
                                TextField(
                                  controller: _groupIdController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: l10n.groupId,
                                    prefixIcon: const Icon(Icons.tag_rounded),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ] else ...[
                                TextField(
                                  controller: _nameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: l10n.groupName,
                                    prefixIcon: const Icon(
                                      Icons.group_work_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              TextField(
                                controller: _inviteCodeController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: l10n.inviteCode,
                                  prefixIcon: const Icon(Icons.key_rounded),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              FilledButton.icon(
                                onPressed: _busy ? null : _submit,
                                icon: _busy
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _joining
                                            ? Icons.group_add_outlined
                                            : Icons.add_rounded,
                                      ),
                                label: Text(title),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final inviteCode = _inviteCodeController.text.trim();
    final l10n = AppLocalizations.of(context);
    if (inviteCode.length < 4) {
      setState(() => _error = l10n.errorInviteCodeLength);
      return;
    }

    final repository = ref.read(accountRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_joining) {
        final groupId = _groupIdController.text.trim();
        if (groupId.isEmpty) {
          throw ArgumentError(l10n.errorGroupIdRequired);
        }
        await repository.joinGroup(groupId: groupId, inviteCode: inviteCode);
      } else {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          throw ArgumentError(l10n.errorGroupNameRequired);
        }
        await repository.createGroup(name: name, inviteCode: inviteCode);
      }
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        setState(() => _busy = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }
}

class _ExistingGroupsCard extends ConsumerWidget {
  const _ExistingGroupsCard({required this.groups, required this.busy});

  final List<AlarmGroupSummary> groups;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activeGroup = ref.watch(activeGroupProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.yourGroups,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.defaultGroupExplanation,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final group in groups)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  activeGroup?.groupId == group.groupId
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: activeGroup?.groupId == group.groupId
                      ? Colors.amber
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(group.name),
                subtitle: Text(group.groupId),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (activeGroup?.groupId == group.groupId) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.defaultGroup,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                        ),
                      ),
                    ],
                    Text(
                      group.role,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _showGroupDetailsDialog(context, ref, group),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: group.groupId));
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(
                                    0xFFB9EFC5,
                                  ), // Stitch Primary Container 그린 컬러
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${group.name}의 그룹 ID가 복사되었습니다.',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(
                              0xEE2C342E,
                            ), // Stitch 메인 텍스트 다크 컬러(#2c342e) 기반 투명 배경
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onTap: busy
                    ? null
                    : () {
                        ref
                            .read(accountRepositoryProvider)
                            .setActiveGroup(group.groupId);
                      },
              ),
          ],
        ),
      ),
    );
  }
}

void _showGroupDetailsDialog(
  BuildContext context,
  WidgetRef ref,
  AlarmGroupSummary group,
) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);

  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.groupDetails,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${l10n.groupName}: ${group.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.groupId}: ${group.groupId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: SingleChildScrollView(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final membersVal = ref.watch(
                          groupMembersFamilyProvider(group.groupId),
                        );
                        final devicesVal = ref.watch(
                          groupDevicesFamilyProvider(group.groupId),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.members,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            membersVal.when(
                              data: (members) {
                                if (members.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Text('참여 중인 멤버가 없습니다.'),
                                  );
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: members.length,
                                  itemBuilder: (context, index) {
                                    final member = members[index];
                                    final isOwner = member.role == 'owner';
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: isOwner
                                            ? theme.colorScheme.primaryContainer
                                            : theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                        child: Icon(
                                          isOwner
                                              ? Icons.star_rounded
                                              : Icons.person_rounded,
                                          color: isOwner
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.outline,
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              member.displayName,
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isOwner) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                '방장',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      subtitle: Text(
                                        member.email,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.outline,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              error: (err, _) => Text('에러: $err'),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              l10n.registeredDevices,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            devicesVal.when(
                              data: (devices) {
                                if (devices.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Text('등록된 기기가 없습니다.'),
                                  );
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: devices.length,
                                  itemBuilder: (context, index) {
                                    final device = devices[index];
                                    final isAndroid =
                                        device.platform.toLowerCase() ==
                                        'android';
                                    final isIOS =
                                        device.platform.toLowerCase() == 'ios';

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        isAndroid
                                            ? Icons.android_rounded
                                            : (isIOS
                                                  ? Icons.phone_iphone_rounded
                                                  : Icons.computer_rounded),
                                        color: theme.colorScheme.primary,
                                      ),
                                      title: Text(
                                        device.displayName,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      subtitle: Text(
                                        '${l10n.lastSynced}: ${_formatLastSeen(device.lastSeenAt, l10n)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.outline,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              error: (err, _) => Text('에러: $err'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _formatLastSeen(DateTime dt, AppLocalizations l10n) {
  final localDt = dt.toLocal();
  final hour = localDt.hour;
  final minute = localDt.minute.toString().padLeft(2, '0');
  final period = hour < 12 ? 'AM' : 'PM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '${localDt.month}/${localDt.day} $hour12:$minute $period';
}
