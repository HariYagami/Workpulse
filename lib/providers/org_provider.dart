import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/organization_model.dart';
import '../services/org_service.dart';

final orgServiceProvider = Provider<OrgService>((ref) => OrgService());

// Stream of all orgs the logged-in user belongs to
// handleError swallows permission-denied on first login — returns empty list
// instead of crashing, which shows _NoOrgGate instead of an error screen
final myOrgsProvider = StreamProvider<List<OrganizationModel>>((ref) {
  return ref.read(orgServiceProvider).streamMyOrgs().handleError((error) {
    return <OrganizationModel>[];
  });
});

// Stream members of a specific org — pass orgId as family argument
final orgMembersProvider =
    StreamProvider.family<List<OrgMember>, String>((ref, orgId) {
  return ref.read(orgServiceProvider).streamMembers(orgId);
});

// Currently selected org (set when admin taps an org card)
final selectedOrgProvider = StateProvider<OrganizationModel?>((ref) => null);
