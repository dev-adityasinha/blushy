import 'package:flutter/material.dart';

import '../../../models/blushy_models.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../shared/api_state_card.dart';

/// Partner Mode sharing controls (spec section 10 "Partner Permissions").
///
/// Everything on this screen is server-enforced: the toggles reflect the
/// backend permission matrix, changes propagate immediately, and only the
/// person sharing can change them. The list also answers "what am I sharing?",
/// which the spec requires the woman to always be able to see.
class PartnerSharingScreen extends StatefulWidget {
  final String connectionId;
  final String? partnerName;

  const PartnerSharingScreen({
    super.key,
    required this.connectionId,
    this.partnerName,
  });

  @override
  State<PartnerSharingScreen> createState() => _PartnerSharingScreenState();
}

class _PartnerSharingScreenState extends State<PartnerSharingScreen> {
  ApiResult<PartnerSharingState> _result = const ApiResult.loading();

  /// Keys currently mid-flight, so a toggle can show progress and cannot be
  /// tapped twice.
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Requests the partner has made and is waiting on.
  List<Map<String, dynamic>> _pendingRequests = const [];
  final Set<String> _answering = <String>{};

  Future<void> _load() async {
    setState(() => _result = const ApiResult.loading());
    final result = await PartnerApi.sharingState(widget.connectionId);
    final requests = await PartnerApi.permissionRequests(widget.connectionId, states: 'pending');
    if (!mounted) return;
    setState(() {
      _result = result;
      _pendingRequests = requests.data ?? const [];
    });
  }

  /// Answers one request. Approving is what turns the permission on; the
  /// request itself never shared anything.
  Future<void> _answerRequest(Map<String, dynamic> request, bool approve) async {
    final requestId = request['requestId']?.toString() ?? '';
    if (requestId.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _answering.add(requestId));

    final response = await PartnerApi.respondToPermissionRequest(requestId, approve: approve);
    if (!mounted) return;

    if (response.data == null) {
      setState(() => _answering.remove(requestId));
      messenger.showSnackBar(
        SnackBar(content: Text(response.errorMessage ?? 'That could not be saved.')),
      );
      return;
    }

    // Re-read rather than patching locally, so what is shown is what the
    // server will actually enforce.
    await _load();
    if (!mounted) return;
    setState(() => _answering.remove(requestId));

    final label = request['permissionLabel']?.toString() ?? 'That';
    messenger.showSnackBar(
      SnackBar(
        content: Text(approve
            ? '$label is now shared.'
            : 'Declined. $label stays private, and they have been told.'),
      ),
    );
  }

  Future<void> _toggle(PartnerPermission permission, bool value) async {
    if (permission.alwaysOn || _saving.contains(permission.key)) return;

    setState(() => _saving.add(permission.key));

    final response = await PartnerApi.updatePermissions(
      widget.connectionId,
      {permission.key: value},
    );

    if (!mounted) return;

    if (response.isReady) {
      // Re-read rather than patching locally, so what is displayed is always
      // what the server will actually enforce.
      await _load();
      if (!mounted) return;
      setState(() => _saving.remove(permission.key));
      _showMessage(
        value
            ? '${permission.label} is now shared.'
            : '${permission.label} is no longer shared. Your partner has lost access.',
      );
      return;
    }

    setState(() => _saving.remove(permission.key));
    _showMessage(
      response.errorCode == 'FORBIDDEN'
          ? 'Only the person sharing can change these settings.'
          : response.errorMessage ?? 'That change could not be saved.',
      isError: true,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final theme = Theme.of(context);
    final requestId = request['requestId']?.toString() ?? '';
    final label = request['permissionLabel']?.toString() ?? 'A category';
    final message = request['message']?.toString();
    final busy = _answering.contains(requestId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              // Named plainly so declining does not feel like a failure.
              'Your partner asked if you would share this. It is entirely your choice.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('"$message"', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _answerRequest(request, false),
                    child: const Text('Not now'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _answerRequest(request, true),
                    child: const Text('Share it'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('What you share'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.partnerName == null
                  ? 'You decide what your partner can see.'
                  : 'You decide what ${widget.partnerName} can see.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Everything is private until you turn it on. Turning something off '
              'removes your partner access straight away.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (_pendingRequests.isNotEmpty) ...[
              Text(
                'THEY ASKED TO SEE',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              ..._pendingRequests.map(_buildRequestCard),
              const SizedBox(height: 20),
            ],
            ApiStateCard<PartnerSharingState>(
              result: _result,
              onRetry: _load,
              emptyMessage: 'This connection is no longer active.',
              restrictedMessage: 'Only the person sharing can view these settings.',
              builder: (context, sharing) {
                if (!sharing.isActive) {
                  return _InactiveNotice(state: sharing.connectionState);
                }

                final shared = sharing.enabled.where((p) => !p.alwaysOn).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryBanner(sharedCount: shared, total: sharing.permissions.length),
                    const SizedBox(height: 12),
                    ...sharing.permissions.map(
                      (permission) => _PermissionTile(
                        permission: permission,
                        saving: _saving.contains(permission.key),
                        onChanged: (value) => _toggle(permission, value),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final int sharedCount;
  final int total;

  const _SummaryBanner({required this.sharedCount, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nothingShared = sharedCount == 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            nothingShared ? Icons.lock_outline : Icons.visibility_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nothingShared
                  ? 'Nothing is shared right now.'
                  : 'You are sharing $sharedCount of $total things.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final PartnerPermission permission;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _PermissionTile({
    required this.permission,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SwitchListTile.adaptive(
        value: permission.enabled,
        // Always-on permissions (a care request is addressed to the partner by
        // definition) are shown but cannot be toggled.
        onChanged: permission.alwaysOn || saving ? null : onChanged,
        title: Row(
          children: [
            Flexible(child: Text(permission.label)),
            if (saving) ...[
              const SizedBox(width: 8),
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
        subtitle: permission.example == null
            ? null
            : Text(
                permission.alwaysOn
                    ? '${permission.example}  •  Always on'
                    : permission.example!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _InactiveNotice extends StatelessWidget {
  final String state;

  const _InactiveNotice({required this.state});

  String get _message {
    switch (state) {
      case 'pending':
        return 'This connection has not been accepted yet. Nothing is shared until it is.';
      case 'blocked':
        return 'This connection is blocked. Nothing is shared.';
      case 'expired':
        return 'This invitation expired. Nothing is shared.';
      default:
        return 'This connection has ended. Your partner no longer has access to anything.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.link_off, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(_message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
