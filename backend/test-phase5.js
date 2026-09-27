const http = require('http');
const crypto = require('crypto');

const BASE_URL = 'http://localhost:4000';

function request(method, path, body = null, token = null, isMultipart = false, multipartData = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const headers = {};

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    let postData = null;

    if (isMultipart && multipartData) {
      const boundary = '----WebKitFormBoundary' + crypto.randomBytes(16).toString('hex');
      headers['Content-Type'] = `multipart/form-data; boundary=${boundary}`;

      const { fieldName, filename, contentType, buffer } = multipartData;
      const pre = Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="${fieldName}"; filename="${filename}"\r\nContent-Type: ${contentType}\r\n\r\n`
      );
      const post = Buffer.from(`\r\n--${boundary}--\r\n`);
      postData = Buffer.concat([pre, buffer, post]);
      headers['Content-Length'] = postData.length;
    } else if (body) {
      postData = JSON.stringify(body);
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(postData);
    }

    const req = http.request(
      url,
      {
        method,
        headers,
      },
      (res) => {
        let rawData = '';
        res.on('data', (chunk) => {
          rawData += chunk;
        });
        res.on('end', () => {
          try {
            const json = rawData ? JSON.parse(rawData) : {};
            resolve({ status: res.statusCode, headers: res.headers, data: json });
          } catch (e) {
            resolve({ status: res.statusCode, headers: res.headers, raw: rawData });
          }
        });
      }
    );

    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

function createDummyPdfBuffer(title = 'Phase 5 Secure Document') {
  return Buffer.from(
    `%PDF-1.4\n1 0 obj\n<< /Title (${title}) /Author (DHA Vault) >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF`
  );
}

let passedTests = 0;
let totalTests = 0;

function assert(condition, message) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  ✓ ${message}`);
  } else {
    console.error(`  ✗ FAIL: ${message}`);
    throw new Error(`Assertion failed: ${message}`);
  }
}

async function runPhase5Tests() {
  console.log('\n============================================================');
  console.log('🛡️  DHA VAULT — PHASE 5 MASTER INTEGRATION TEST SUITE');
  console.log('   Family Vault, Advanced Sharing, E2EE, Emergency & Recovery');
  console.log('============================================================\n');

  const ts = Date.now();
  const ownerEmail = `dha_owner_${ts}@dhavault.io`;
  const memberEmail = `dha_member_${ts}@dhavault.io`;
  const viewerEmail = `dha_viewer_${ts}@dhavault.io`;
  const delegateEmail = `dha_delegate_${ts}@dhavault.io`;
  const outsiderEmail = `dha_outsider_${ts}@dhavault.io`;
  const password = 'Password@123';

  // --- Step 1: User Registrations ---
  console.log('--- Step 1: User Registrations & Identities ---');
  const regOwner = await request('POST', '/auth/register', { email: ownerEmail, password, fullName: 'Dhanush Owner' });
  assert(regOwner.status === 201, 'Owner registered successfully');
  const ownerToken = regOwner.data.accessToken;
  const ownerId = regOwner.data.user.id;

  const regMember = await request('POST', '/auth/register', { email: memberEmail, password, fullName: 'Alice Member' });
  assert(regMember.status === 201, 'Member user registered');
  const memberToken = regMember.data.accessToken;
  const memberId = regMember.data.user.id;

  const regViewer = await request('POST', '/auth/register', { email: viewerEmail, password, fullName: 'Bob Viewer' });
  assert(regViewer.status === 201, 'Viewer user registered');
  const viewerToken = regViewer.data.accessToken;
  const viewerId = regViewer.data.user.id;

  const regDelegate = await request('POST', '/auth/register', { email: delegateEmail, password, fullName: 'Charlie Delegate' });
  assert(regDelegate.status === 201, 'Delegate user registered');
  const delegateToken = regDelegate.data.accessToken;
  const delegateId = regDelegate.data.user.id;

  const regOutsider = await request('POST', '/auth/register', { email: outsiderEmail, password, fullName: 'Eve Outsider' });
  assert(regOutsider.status === 201, 'Outsider user registered');
  const outsiderToken = regOutsider.data.accessToken;
  const outsiderId = regOutsider.data.user.id;

  // --- Step 2: Family Vault Creation & Management ---
  console.log('\n--- Step 2: Family Vault Creation & Settings ---');
  const createFamily = await request('POST', '/families', { name: 'AV Family Vault' }, ownerToken);
  assert(createFamily.status === 201, 'Family Vault created successfully');
  const familyId = createFamily.data.id;
  assert(createFamily.data.name === 'AV Family Vault', 'Family vault name matches');
  assert(createFamily.data.ownerId === ownerId, 'Family owner is caller');

  // List families
  const listFamilies = await request('GET', '/families', null, ownerToken);
  assert(listFamilies.status === 200, 'List families returns 200');
  assert(listFamilies.data.some((f) => f.id === familyId), 'Created family appears in list');

  // View family details
  const getFamily = await request('GET', `/families/${familyId}`, null, ownerToken);
  assert(getFamily.status === 200, 'Get family details returns 200');
  assert(getFamily.data.currentUserRole === 'OWNER', 'Caller role evaluated as OWNER');

  // Update family settings
  const updateFamily = await request('PATCH', `/families/${familyId}`, { name: 'Dhanush & Family Vault' }, ownerToken);
  assert(updateFamily.status === 200, 'Owner updated family vault name');
  assert(updateFamily.data.name === 'Dhanush & Family Vault', 'Updated name persisted');

  // Non-member access attempt (Outsider)
  const outsiderFamilyAccess = await request('GET', `/families/${familyId}`, null, outsiderToken);
  assert(outsiderFamilyAccess.status === 403, 'Outsider forbidden from viewing family (403)');

  // --- Step 3: Family Invitations & Acceptance ---
  console.log('\n--- Step 3: Family Invitations & Single-Use Tokens ---');
  const inviteMember = await request('POST', `/families/${familyId}/invitations`, { email: memberEmail, role: 'MEMBER' }, ownerToken);
  assert(inviteMember.status === 201, 'Owner sent family invitation');
  assert(inviteMember.data.token && inviteMember.data.token.length > 20, 'Cryptographic token returned');
  const memberInviteToken = inviteMember.data.token;

  // Invite viewer
  const inviteViewer = await request('POST', `/families/${familyId}/invitations`, { email: viewerEmail, role: 'VIEWER' }, ownerToken);
  assert(inviteViewer.status === 201, 'Owner invited viewer');
  const viewerInviteToken = inviteViewer.data.token;

  // Outsider cannot invite members
  const outsiderInvite = await request('POST', `/families/${familyId}/invitations`, { email: outsiderEmail, role: 'MEMBER' }, outsiderToken);
  assert(outsiderInvite.status === 403, 'Outsider cannot send family invitations (403)');

  // Member accepts invitation
  const acceptMember = await request('POST', `/families/invitations/${memberInviteToken}/accept`, null, memberToken);
  assert(acceptMember.status === 200, 'Member accepted invitation successfully');
  assert(acceptMember.data.role === 'MEMBER', 'Membership role is MEMBER');

  // Viewer accepts invitation
  const acceptViewer = await request('POST', `/families/invitations/${viewerInviteToken}/accept`, null, viewerToken);
  assert(acceptViewer.status === 200, 'Viewer accepted invitation');
  assert(acceptViewer.data.role === 'VIEWER', 'Membership role is VIEWER');

  // Re-acceptance attempt of already accepted token must fail
  const reAccept = await request('POST', `/families/invitations/${memberInviteToken}/accept`, null, memberToken);
  assert(reAccept.status === 400, 'Re-using accepted invitation token fails (400 single-use)');

  // Members list check
  const membersList = await request('GET', `/families/${familyId}/members`, null, ownerToken);
  assert(membersList.status === 200, 'List family members returns 200');
  assert(membersList.data.length >= 3, 'All 3 members listed (Owner, Member, Viewer)');

  // --- Step 4: Role-Based Permissions & Privilege Escalation Checks ---
  console.log('\n--- Step 4: Role Permissions & Privilege Escalation Prevention ---');
  // Viewer cannot invite someone
  const viewerInviteAttempt = await request('POST', `/families/${familyId}/invitations`, { email: 'test@dhavault.io', role: 'MEMBER' }, viewerToken);
  assert(viewerInviteAttempt.status === 403, 'Viewer forbidden from inviting members (403)');

  // Member cannot change roles
  const memberChangeRole = await request('PATCH', `/families/${familyId}/members/${viewerId}/role`, { role: 'OWNER' }, memberToken);
  assert(memberChangeRole.status === 403, 'Member forbidden from changing roles (403)');

  // Owner changes Viewer to MEMBER
  const ownerPromote = await request('PATCH', `/families/${familyId}/members/${viewerId}/role`, { role: 'MEMBER' }, ownerToken);
  assert(ownerPromote.status === 200, 'Owner promoted Viewer to MEMBER');
  assert(ownerPromote.data.role === 'MEMBER', 'Role updated to MEMBER');

  // Owner cannot demote self without transfer
  const demoteSelf = await request('PATCH', `/families/${familyId}/members/${ownerId}/role`, { role: 'MEMBER' }, ownerToken);
  assert(demoteSelf.status === 400, 'Primary owner cannot demote self (400)');

  // --- Step 5: Document Upload & Family Document Sharing ---
  console.log('\n--- Step 5: Document Upload & Family Document Sharing ---');
  // Owner uploads a personal document
  const pdfBuffer = createDummyPdfBuffer('Family Medical Insurance 2026');
  const uploadRes = await request('POST', '/documents/upload', null, ownerToken, true, {
    fieldName: 'file',
    filename: 'insurance.pdf',
    contentType: 'application/pdf',
    buffer: pdfBuffer,
  });
  assert(uploadRes.status === 200, 'Document binary uploaded');

  const createDoc = await request('POST', '/documents', {
    title: 'Family Health Insurance Policy',
    documentType: 'INSURANCE',
    storagePath: uploadRes.data.storagePath,
    fileSize: uploadRes.data.fileSize,
    mimeType: uploadRes.data.mimeType,
  }, ownerToken);
  assert(createDoc.status === 201, 'Document created in personal vault');
  const docId = createDoc.data.id;

  // Share document to family vault
  const shareToFamily = await request('POST', `/families/${familyId}/documents/${docId}/share`, {
    permissions: ['VIEW', 'DOWNLOAD'],
  }, ownerToken);
  assert(shareToFamily.status === 201, 'Document shared to Family Vault');

  // Member views family documents
  const memberFamilyDocs = await request('GET', `/families/${familyId}/documents`, null, memberToken);
  assert(memberFamilyDocs.status === 200, 'Member retrieves family documents');
  assert(memberFamilyDocs.data.some((d) => d.document.id === docId), 'Shared document appears in family document feed');

  // Outsider cannot view family documents
  const outsiderFamilyDocs = await request('GET', `/families/${familyId}/documents`, null, outsiderToken);
  assert(outsiderFamilyDocs.status === 403, 'Outsider forbidden from family documents (403)');

  // Revoke document access from family
  const revokeFamilyDoc = await request('DELETE', `/families/${familyId}/documents/${docId}/access/all`, null, ownerToken);
  assert(revokeFamilyDoc.status === 200, 'Document revoked from family vault');

  const memberDocsAfterRevoke = await request('GET', `/families/${familyId}/documents`, null, memberToken);
  assert(!memberDocsAfterRevoke.data.some((d) => d.document.id === docId), 'Revoked document no longer visible to family');

  // --- Step 6: Advanced Secure Sharing (User-to-User E2EE) ---
  console.log('\n--- Step 6: Advanced User-to-User Sharing & Key Envelopes ---');
  // Share document directly from Owner to Member with maxViews: 2
  const fakeKeyEnvelope = {
    wrappedKey: crypto.randomBytes(32).toString('base64'),
    iv: crypto.randomBytes(12).toString('hex'),
    authTag: crypto.randomBytes(16).toString('hex'),
    version: 1,
  };

  const createShare = await request('POST', '/shares/user', {
    documentId: docId,
    recipientEmail: memberEmail,
    permissions: ['VIEW', 'DOWNLOAD'],
    maxViews: 2,
    expiresInHours: 24,
    watermarkText: 'CONFIDENTIAL - DHA VAULT',
    keyEnvelope: fakeKeyEnvelope,
  }, ownerToken);

  assert(createShare.status === 201, 'User-to-user share created with key envelope');
  const shareId = createShare.data.id;
  assert(createShare.data.maxViews === 2, 'Max views set to 2');
  assert(createShare.data.status === 'ACTIVE', 'Initial status is ACTIVE');

  // Owner views outgoing shares
  const outgoingShares = await request('GET', '/shares/outgoing', null, ownerToken);
  assert(outgoingShares.status === 200, 'Outgoing shares retrieved');
  assert(outgoingShares.data.some((s) => s.id === shareId), 'Share appears in outgoing list');

  // Member views incoming shares
  const incomingShares = await request('GET', '/shares/incoming', null, memberToken);
  assert(incomingShares.status === 200, 'Incoming shares retrieved');
  assert(incomingShares.data.some((s) => s.id === shareId), 'Share appears in incoming list');

  // Member opens share - 1st view
  const open1 = await request('POST', `/shares/${shareId}/open`, null, memberToken);
  assert(open1.status === 200, '1st share open succeeds');
  assert(open1.data.viewCount === 1, 'View count incremented to 1');
  assert(open1.data.keyEnvelope != null, 'Key envelope delivered to recipient');
  assert(open1.data.watermarkText === 'CONFIDENTIAL - DHA VAULT', 'Watermark text preserved');

  // Member downloads share binary
  const downloadShare = await request('POST', `/shares/${shareId}/download`, null, memberToken);
  if (downloadShare.status !== 200) {
    console.error('Download share failed with:', downloadShare.status, downloadShare.data || downloadShare.raw);
  }
  assert(downloadShare.status === 200 || downloadShare.status === 201, 'Member downloaded shared file binary');

  // Member opens share - 2nd view (Reaches max views)
  const open2 = await request('POST', `/shares/${shareId}/open`, null, memberToken);
  assert(open2.status === 200, '2nd share open succeeds');
  assert(open2.data.viewCount === 2, 'View count reached 2');

  // Member opens share - 3rd view (Must fail due to MAX_VIEWS_REACHED)
  const open3 = await request('POST', `/shares/${shareId}/open`, null, memberToken);
  assert(open3.status === 403, '3rd share open denied (403 MAX_VIEWS_REACHED)');

  // Outsider cannot access share
  const outsiderShareAccess = await request('GET', `/shares/${shareId}`, null, outsiderToken);
  assert(outsiderShareAccess.status === 403, 'Outsider forbidden from accessing share (403)');

  // --- Step 7: Emergency Access & Controlled Safety Window ---
  console.log('\n--- Step 7: Emergency Access & Controlled Safety Window ---');
  // Owner sets up emergency delegate with 48h delay and scoped doc
  const createEmergency = await request('POST', '/emergency-access', {
    delegateEmail,
    activationDelayHours: 48,
    scope: 'SELECTED_DOCUMENTS',
    selectedDocIds: [docId],
    notes: 'In case of medical emergency, access health policy.',
  }, ownerToken);
  assert(createEmergency.status === 201, 'Emergency delegate created with 48h activation delay');
  const emergencyId = createEmergency.data.id;
  assert(createEmergency.data.status === 'ACTIVE', 'Initial state is ACTIVE (dormant)');

  // Delegate lists emergency delegations
  const listEmergency = await request('GET', '/emergency-access', null, delegateToken);
  assert(listEmergency.status === 200, 'Delegate listed emergency contacts');
  assert(listEmergency.data.some((e) => e.id === emergencyId), 'Delegation listed');

  // Delegate triggers activation
  const triggerActivation = await request('POST', `/emergency-access/${emergencyId}/activate`, null, delegateToken);
  assert(triggerActivation.status === 200, 'Emergency activation triggered');
  assert(triggerActivation.data.status === 'TRIGGERED', 'Status changed to TRIGGERED');
  assert(triggerActivation.data.remainingSeconds > 0, 'Safety countdown active');

  // Documents must NOT be accessible during waiting period!
  const docsDuringWait = await request('GET', `/emergency-access/${emergencyId}/documents`, null, delegateToken);
  assert(docsDuringWait.status === 403, 'Documents forbidden during waiting window (403)');

  // Owner cancels the activation
  const cancelActivation = await request('POST', `/emergency-access/${emergencyId}/cancel`, null, ownerToken);
  assert(cancelActivation.status === 200, 'Owner cancelled emergency activation during safety window');
  assert(cancelActivation.data.emergency.status === 'ACTIVE', 'Status restored to ACTIVE');

  // Immediate Emergency Access Test (activationDelayHours = 0)
  console.log('\n--- Step 7b: Immediate Emergency Access Activation & Scoped Docs ---');
  const createImmediateEmergency = await request('POST', '/emergency-access', {
    delegateEmail,
    activationDelayHours: 0, // Instant for testing
    scope: 'SELECTED_DOCUMENTS',
    selectedDocIds: [docId],
  }, ownerToken);
  assert(createImmediateEmergency.status === 201, 'Immediate emergency delegate configured');
  const immediateId = createImmediateEmergency.data.id;

  const triggerImmediate = await request('POST', `/emergency-access/${immediateId}/activate`, null, delegateToken);
  assert(triggerImmediate.status === 200, 'Immediate activation triggered');
  assert(triggerImmediate.data.status === 'COMPLETED', 'Status transitioned to COMPLETED');
  assert(triggerImmediate.data.isFullyActivated === true, 'isFullyActivated is true');

  // Delegate fetches scoped documents
  const scopedDocs = await request('GET', `/emergency-access/${immediateId}/documents`, null, delegateToken);
  assert(scopedDocs.status === 200, 'Delegate retrieved scoped emergency documents');
  assert(scopedDocs.data.length === 1 && scopedDocs.data[0].id === docId, 'Only explicitly scoped documents returned');

  // --- Step 8: Recovery Delegation ---
  console.log('\n--- Step 8: Recovery Delegation ---');
  const fakeRecoveryShard = {
    keyShard: crypto.randomBytes(32).toString('base64'),
    algorithm: 'shamir-shard-aes256',
  };

  const createRecovery = await request('POST', '/recovery-delegations', {
    delegateEmail,
    recoveryPayload: fakeRecoveryShard,
    expiresInDays: 30,
  }, ownerToken);
  assert(createRecovery.status === 201, 'Recovery delegation created');
  const recoveryId = createRecovery.data.id;

  // Delegate accepts recovery delegation
  const acceptRecovery = await request('POST', `/recovery-delegations/${recoveryId}/accept`, null, delegateToken);
  assert(acceptRecovery.status === 200, 'Delegate accepted recovery delegation');
  assert(acceptRecovery.data.delegation.status === 'ACTIVE', 'Status updated to ACTIVE');

  // Owner revokes recovery delegation
  const revokeRecovery = await request('POST', `/recovery-delegations/${recoveryId}/revoke`, null, ownerToken);
  assert(revokeRecovery.status === 200, 'Owner revoked recovery delegation');
  assert(revokeRecovery.data.delegation.status === 'REVOKED', 'Status updated to REVOKED');

  // --- Step 9: Notifications & Audit Verification ---
  console.log('\n--- Step 9: Notifications & Audit Log Verification ---');
  const notifications = await request('GET', '/notifications', null, ownerToken);
  assert(notifications.status === 200, 'Owner retrieved notifications');
  assert(notifications.data.items.length > 0, 'Notifications triggered across family and sharing actions');

  console.log('\n============================================================');
  console.log(`✅ ALL PHASE 5 INTEGRATION TESTS PASSED (${passedTests}/${totalTests})`);
  console.log('============================================================\n');
}

runPhase5Tests().catch((err) => {
  console.error('\n❌ Phase 5 Test Suite Failed:', err.message);
  process.exit(1);
});
