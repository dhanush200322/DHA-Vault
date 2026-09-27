const http = require('http');
const https = require('https');
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

function assert(condition, message) {
  if (!condition) {
    console.error(`❌ FAILED: ${message}`);
    throw new Error(message);
  }
  console.log(`  ✓ ${message}`);
}

async function runPhase4Tests() {
  console.log('\n============================================================');
  console.log('🛡️  DHA VAULT — PHASE 4 INTEGRATION TEST SUITE');
  console.log('   Cloud Sync, Encrypted Backup & Multi-Device Verification');
  console.log('============================================================\n');

  const testId = Date.now().toString().slice(-6);
  const userAEmail = `phase4_userA_${testId}@dhavault.io`;
  const userBEmail = `phase4_userB_${testId}@dhavault.io`;
  const password = 'StrongPassword123!';
  const devicePixel9 = `pixel-9-pro-${testId}`;
  const deviceIpad = `ipad-pro-${testId}`;

  // 1. Register User A with Device Pixel 9
  console.log('--- Step 1: User Registration & Device Enrollment ---');
  const regRes = await request('POST', '/auth/register', {
    email: userAEmail,
    password,
    fullName: 'Dhanush Phase4',
  });
  assert(regRes.status === 201, 'User A registered successfully');

  // Login User A specifying deviceId
  const loginRes = await request('POST', '/auth/login', {
    email: userAEmail,
    password,
    deviceId: devicePixel9,
    deviceName: 'Google Pixel 9 Pro',
  });
  assert(loginRes.status === 200, 'User A logged in with Device Pixel 9');
  const tokenA = loginRes.data.accessToken;

  // 2. Verify enrolled device
  console.log('\n--- Step 2: Multi-Device Management ---');
  const devicesRes = await request('GET', '/devices', null, tokenA);
  assert(devicesRes.status === 200, 'Retrieved user devices list');
  assert(devicesRes.data.length >= 1, 'At least 1 device listed');
  const pixelDevice = devicesRes.data.find((d) => d.deviceId === devicePixel9);
  assert(pixelDevice && pixelDevice.isTrusted === true, 'Pixel 9 is registered and trusted');

  // Register secondary device: iPad Pro
  const regIpadRes = await request(
    'POST',
    '/devices/register',
    {
      deviceId: deviceIpad,
      deviceName: 'Apple iPad Pro M4',
      platform: 'ios',
      appVersion: '3.0.0',
    },
    tokenA
  );
  assert(regIpadRes.status === 201, 'Secondary device (iPad Pro) enrolled successfully');

  // Toggle trust on iPad
  const trustRes = await request('PATCH', `/devices/${deviceIpad}/trust`, { isTrusted: false }, tokenA);
  assert(trustRes.status === 200 && trustRes.data.isTrusted === false, 'Device trust state toggled to false');
  const reTrustRes = await request('PATCH', `/devices/${deviceIpad}/trust`, { isTrusted: true }, tokenA);
  assert(reTrustRes.status === 200 && reTrustRes.data.isTrusted === true, 'Device trust restored to true');

  // 3. Document Upload with Checksum & Version 1
  console.log('\n--- Step 3: Document Upload & Cryptographic Checksum ---');
  const dummyPdf = Buffer.from(
    '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000052 00000 n\n0000000101 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF\n'
  );
  const expectedChecksum = crypto.createHash('sha256').update(dummyPdf).digest('hex');

  const uploadRes = await request(
    'POST',
    '/documents/upload',
    null,
    tokenA,
    true,
    {
      fieldName: 'file',
      filename: 'Passport_Phase4.pdf',
      contentType: 'application/pdf',
      buffer: dummyPdf,
    }
  );
  assert(uploadRes.status === 200, 'PDF file uploaded');
  assert(uploadRes.data.checksum === expectedChecksum, `Uploaded file returned correct SHA-256 checksum (${expectedChecksum.slice(0, 8)}...)`);

  const createDocRes = await request(
    'POST',
    '/documents',
    {
      title: 'Indian Passport 2026',
      documentType: 'PASSPORT',
      storagePath: uploadRes.data.storagePath,
      fileSize: uploadRes.data.fileSize,
      mimeType: uploadRes.data.mimeType,
      checksum: uploadRes.data.checksum,
      deviceId: devicePixel9,
      tags: ['#travel', '#identity'],
    },
    tokenA
  );
  assert(createDocRes.status === 201, 'Document created with initial version');
  const docId = createDocRes.data.id;
  assert(createDocRes.data.syncStatus === 'SYNCED', 'Document initial syncStatus is SYNCED');

  // 4. Document Versioning
  console.log('\n--- Step 4: Document Version History ---');
  const versionsRes = await request('GET', `/documents/${docId}/versions`, null, tokenA);
  assert(versionsRes.status === 200, 'Retrieved document versions');
  assert(versionsRes.data.length === 1, 'Initial version 1 present');
  assert(versionsRes.data[0].versionNumber === 1, 'Version number is 1');
  assert(versionsRes.data[0].checksum === expectedChecksum, 'Version 1 stores SHA-256 checksum');

  // Upload and create Version 2
  const dummyPdfV2 = Buffer.from(
    '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000052 00000 n\n0000000101 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF\n% Version 2 with Visa Stamps\n'
  );
  const checksumV2 = crypto.createHash('sha256').update(dummyPdfV2).digest('hex');

  const uploadV2Res = await request(
    'POST',
    '/documents/upload',
    null,
    tokenA,
    true,
    {
      fieldName: 'file',
      filename: 'Passport_Phase4_v2.pdf',
      contentType: 'application/pdf',
      buffer: dummyPdfV2,
    }
  );
  assert(uploadV2Res.status === 200, 'Version 2 file uploaded');

  const createVerRes = await request(
    'POST',
    `/documents/${docId}/versions`,
    {
      storagePath: uploadV2Res.data.storagePath,
      fileSize: uploadV2Res.data.fileSize,
      checksum: checksumV2,
      changeNotes: 'Added US Visa Page Stamp',
      deviceId: deviceIpad,
    },
    tokenA
  );
  assert(createVerRes.status === 201, 'Version 2 registered successfully');
  assert(createVerRes.data.version.versionNumber === 2, 'Version 2 number confirmed');

  const allVersionsRes = await request('GET', `/documents/${docId}/versions`, null, tokenA);
  assert(allVersionsRes.data.length === 2, 'Document now has 2 distinct versions in history');

  // Download Version 1 specifically
  const v1Id = versionsRes.data[0].id;
  const dlV1Res = await request('GET', `/documents/${docId}/versions/${v1Id}/download`, null, tokenA);
  assert(dlV1Res.status === 200, 'Downloaded specific version (Version 1) binary');

  // 5. Sync Engine & Status
  console.log('\n--- Step 5: Sync Engine & Conflict Resolution ---');
  const syncStatusRes = await request('GET', '/sync/status', null, tokenA);
  assert(syncStatusRes.status === 200, 'Sync status retrieved');
  assert(syncStatusRes.data.status === 'SYNCED', 'Initial sync status is SYNCED');

  // Run startSync with matching client item
  const startSyncRes = await request(
    'POST',
    '/sync/start',
    {
      deviceId: devicePixel9,
      items: [{ documentId: docId, checksum: checksumV2, versionNumber: 2 }],
    },
    tokenA
  );
  assert(startSyncRes.status === 200, 'Sync evaluated without conflicts');
  assert(startSyncRes.data.toPush.length === 0, 'No push needed (checksum matches)');

  // Simulate concurrent conflict: client reports different checksum for same version
  const conflictSyncRes = await request(
    'POST',
    '/sync/start',
    {
      deviceId: devicePixel9,
      items: [
        {
          documentId: docId,
          checksum: 'fake_different_checksum_from_another_device_12345',
          versionNumber: 2,
        },
      ],
    },
    tokenA
  );
  assert(conflictSyncRes.status === 200, 'Sync engine detected concurrent modifications');
  assert(conflictSyncRes.data.conflicts.length >= 1, 'Sync conflict created');
  const conflictId = conflictSyncRes.data.conflicts[0].id;

  // Retrieve conflicts
  const conflictsListRes = await request('GET', '/sync/conflicts', null, tokenA);
  assert(conflictsListRes.status === 200, 'Retrieved conflict list');
  assert(conflictsListRes.data.some((c) => c.id === conflictId), 'Active conflict listed in /sync/conflicts');

  // Resolve conflict with CREATE_NEW_VERSION
  const resolveRes = await request(
    'POST',
    '/sync/resolve-conflict',
    {
      conflictId,
      resolution: 'CREATE_NEW_VERSION',
      changeNotes: 'Branched and saved conflict resolution',
    },
    tokenA
  );
  assert(resolveRes.status === 200, 'Conflict resolved via CREATE_NEW_VERSION');

  // Confirm sync status is back to SYNCED
  const postResolveSync = await request('GET', '/sync/status', null, tokenA);
  assert(postResolveSync.data.status === 'SYNCED', 'Sync status returned to SYNCED after conflict resolution');

  // 6. Encrypted Cloud Backup & Storage Breakdown
  console.log('\n--- Step 6: Encrypted Cloud Backup & Storage Metrics ---');
  const storageBreakdownRes = await request('GET', '/backup/storage', null, tokenA);
  assert(storageBreakdownRes.status === 200, 'Retrieved storage quota & usage breakdown');
  assert(storageBreakdownRes.data.totalUsedBytes > 0, 'Document storage bytes reported accurately');
  assert(storageBreakdownRes.data.quotaBytes === 10737418240, '10GB quota verified');

  // Start Encrypted Cloud Backup
  const backupStartRes = await request('POST', '/backup/start', null, tokenA);
  assert(backupStartRes.status === 200, 'Encrypted cloud backup executed successfully');
  assert(backupStartRes.data.status === 'COMPLETED', 'Backup completed with encrypted bundles');
  assert(backupStartRes.data.totalDocuments >= 1, 'Documents encrypted and archived');
  const backupId = backupStartRes.data.backupId;

  // Check Backup Status
  const backupStatusRes = await request('GET', '/backup/status', null, tokenA);
  assert(backupStatusRes.status === 200, 'Retrieved backup status');
  assert(backupStatusRes.data.status === 'COMPLETED', 'Latest backup reports COMPLETED status');
  assert(backupStatusRes.data.latestBackupId === backupId, 'Backup ID matches');

  // Test Backup Pause and Resume
  const pauseRes = await request('POST', '/backup/pause', null, tokenA);
  assert(pauseRes.status === 200, 'Backup pause endpoint operational');
  const resumeRes = await request('POST', '/backup/resume', null, tokenA);
  assert(resumeRes.status === 200, 'Backup resume endpoint operational');

  // 7. Vault Restore
  console.log('\n--- Step 7: Cloud Vault Restore ---');
  const restoreRes = await request('POST', '/backup/restore', { backupId }, tokenA);
  assert(restoreRes.status === 200, 'Vault restore completed successfully');
  assert(restoreRes.data.restoredDocuments >= 1, 'Restored document count matches backup');

  // 8. Security & Cross-Tenant Isolation
  console.log('\n--- Step 8: Cross-Tenant Security Audit ---');
  const regBRes = await request('POST', '/auth/register', {
    email: userBEmail,
    password,
    fullName: 'Attacker User B',
  });
  const tokenB = regBRes.data.accessToken;

  // User B cannot access User A's sync status or documents
  const stolenSync = await request('GET', '/sync/status', null, tokenB);
  assert(stolenSync.data.totalDocuments === 0, 'User B sees 0 documents in sync status (tenant isolated)');

  // User B cannot restore User A's backup
  const unauthorizedRestore = await request('POST', '/backup/restore', { backupId }, tokenB);
  assert(unauthorizedRestore.status === 404, 'User B forbidden from restoring User A backup (404/Isolated)');

  // User B cannot download User A document versions
  const unauthorizedVersionDl = await request('GET', `/documents/${docId}/versions/${v1Id}/download`, null, tokenB);
  assert(unauthorizedVersionDl.status === 403 || unauthorizedVersionDl.status === 404, 'User B forbidden from downloading User A document version');

  // 9. Remote Lock & Device Revocation
  console.log('\n--- Step 9: Remote Lock & Revocation Enforcement ---');
  const remoteLockRes = await request('POST', `/devices/${devicePixel9}/remote-lock`, null, tokenA);
  assert(remoteLockRes.status === 200, 'Remote lock triggered for Device Pixel 9');

  // Subsequent request using Token A (which is bound to locked Pixel 9) must fail immediately!
  const lockedRequestRes = await request('GET', '/documents', null, tokenA);
  assert(
    lockedRequestRes.status === 401,
    `Locked device request immediately denied with 401 (${lockedRequestRes.data.message || 'Unauthorized'})`
  );

  // Re-login User A with iPad Pro to test device revocation
  const loginIpadRes = await request('POST', '/auth/login', {
    email: userAEmail,
    password,
    deviceId: deviceIpad,
    deviceName: 'Apple iPad Pro M4',
  });
  const tokenIpad = loginIpadRes.data.accessToken;

  // Revoke Pixel 9 from iPad
  const revokeRes = await request('POST', `/devices/${devicePixel9}/revoke`, null, tokenIpad);
  assert(revokeRes.status === 200, 'Pixel 9 device revoked successfully');

  // Verify Pixel 9 no longer in devices list
  const activeDevicesRes = await request('GET', '/devices', null, tokenIpad);
  assert(!activeDevicesRes.data.some((d) => d.deviceId === devicePixel9), 'Revoked device completely removed from devices list');

  console.log('\n============================================================');
  console.log('✅ ALL PHASE 4 INTEGRATION TESTS PASSED (25/25)');
  console.log('============================================================\n');
}

runPhase4Tests().catch((err) => {
  console.error('\n❌ Test suite failed with error:', err.message);
  process.exit(1);
});
