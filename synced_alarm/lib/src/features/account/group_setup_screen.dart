import 'package:flutter/material.dart';
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  ],
                ),
                onTap: busy
                    ? null
                    : () {
                        ref
                            .read(accountRepositoryProvider)
                            .setActiveGroup(group.groupId);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${group.name}이(가) 기본 생성 그룹으로 지정되었습니다.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );

                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }
}
