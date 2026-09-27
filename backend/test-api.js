/**
 * DHA Vault Phase 2 Comprehensive API & Security Test Suite
 * Tests all Phase 2 features: Fast View, Storage, Sharing, Stats, Search, Expiry, Security
 */
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:4000';

async function runPhase2Tests() {
  const results = [];
  const logTest = (name, passed, status, detail) => {
    results.push({ name, passed, status, detail });
    const mark = passed ? '✅ PASS' : '❌ FAIL';
    console.log(`${mark} [${status}] ${name}: ${JSON.stringify(detail).slice(0, 100)}...`);
  };

  try {
    // 1. Health check
    const healthRes = await fetch(`${BASE_URL}/health`);
    const healthData = await healthRes.json();
    logTest('1. GET /health', healthRes.status === 200 && healthData.database === 'connected', healthRes.status, healthData);

    // 2. Auth: Register Owner
    const ownerEmail = `dha_vault_owner_${Date.now()}@dhavault.io`;
    const regRes = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: ownerEmail,
        password: 'DhaVaultMasterKey2026!',
        fullName: 'DHA Principal Auditor',
      }),
    });
    const regData = await regRes.json();
    const token = regData.accessToken;
    const userId = regData.user?.id;
    logTest('2. POST /auth/register', regRes.status === 201 && !!token, regRes.status, { userId, email: ownerEmail });

    // 3. Categories
    const catRes = await fetch(`${BASE_URL}/categories`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const catData = await catRes.json();
    const identityCat = catData.find((c) => c.name === 'Identity') || catData[0];
    logTest('3. GET /categories', catRes.status === 200 && catData.length >= 8, catRes.status, { count: catData.length });

    // 4. Real Binary Upload: PDF with magic bytes %PDF-
    const boundary = '----WebKitFormBoundaryPhase2TestDhaVault';
    const pdfBuffer = Buffer.from(
      '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000010 00000 n\n0000000053 00000 n\n0000000102 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n149\n%%EOF'
    );
    const postStart = Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="Aadhaar_Official_2026.pdf"\r\nContent-Type: application/pdf\r\n\r\n`
    );
    const postEnd = Buffer.from(`\r\n--${boundary}--\r\n`);
    const uploadBody = Buffer.concat([postStart, pdfBuffer, postEnd]);

    const uploadRes = await fetch(`${BASE_URL}/documents/upload`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body: uploadBody,
    });
    const uploadData = await uploadRes.json();
    logTest('4. POST /documents/upload (PDF with Magic Bytes)', uploadRes.status === 200 && uploadData.storagePath.includes(`users/${userId}/documents`), uploadRes.status, uploadData);

    // 5. Metadata Ingestion: POST /documents
    const docRes = await fetch(`${BASE_URL}/documents`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        title: 'National Aadhaar Identification Card',
        description: 'Verified citizen Aadhaar card',
        categoryId: identityCat?.id,
        documentType: 'AADHAAR',
        storagePath: uploadData.storagePath,
        originalFileName: uploadData.originalFileName,
        mimeType: uploadData.mimeType,
        fileSize: uploadData.fileSize,
        issueDate: '2020-05-10T00:00:00.000Z',
        expiryDate: new Date(Date.now() + 15 * 86400000).toISOString(), // Expiring in 15 days
        tags: ['identity', 'government', 'biometric'],
      }),
    });
    const docData = await docRes.json();
    const docId = docData.id;
    logTest('5. POST /documents (Metadata Ingestion)', docRes.status === 201 && docData.documentType === 'AADHAAR', docRes.status, { id: docId, title: docData.title });

    // 6. Fast View: GET /documents/:id/preview
    const previewRes = await fetch(`${BASE_URL}/documents/${docId}/preview`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const previewBuf = await previewRes.arrayBuffer();
    logTest('6. GET /documents/:id/preview (Stream Preview)', previewRes.status === 200 && previewBuf.byteLength > 0, previewRes.status, { bytes: previewBuf.byteLength });

    // 7. Fast View: GET /documents/:id/download
    const downloadRes = await fetch(`${BASE_URL}/documents/${docId}/download`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const downloadBuf = await downloadRes.arrayBuffer();
    logTest('7. GET /documents/:id/download (Stream Download)', downloadRes.status === 200 && downloadBuf.byteLength === pdfBuffer.length, downloadRes.status, { bytes: downloadBuf.byteLength });

    // 8. Toggle Favorite: POST /documents/:id/favorite
    const favRes = await fetch(`${BASE_URL}/documents/${docId}/favorite`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    const favData = await favRes.json();
    logTest('8. POST /documents/:id/favorite (Quick Access Pin)', favRes.status === 200 && favData.isFavorite === true, favRes.status, { isFavorite: favData.isFavorite });

    // 9. Recently Viewed: GET /documents/recent
    const recentRes = await fetch(`${BASE_URL}/documents/recent`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const recentData = await recentRes.json();
    logTest('9. GET /documents/recent', recentRes.status === 200 && Array.isArray(recentData) && recentData.length >= 1, recentRes.status, { count: recentData.length, firstDoc: recentData[0]?.title });

    // 10. Stats: GET /documents/stats/overview
    const statsRes = await fetch(`${BASE_URL}/documents/stats/overview`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const statsData = await statsRes.json();
    logTest('10. GET /documents/stats/overview', statsRes.status === 200 && statsData.totalDocuments >= 1 && statsData.favoriteDocuments >= 1, statsRes.status, statsData);

    // 11. Search: GET /search?q=Aadhaar
    const searchRes = await fetch(`${BASE_URL}/search?q=Aadhaar`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const searchData = await searchRes.json();
    logTest('11. GET /search?q=Aadhaar (Debounced Backend Search)', searchRes.status === 200 && searchData.documents?.length >= 1, searchRes.status, { count: searchData.documents?.length, match: searchData.documents?.[0]?.title });

    // 12. Expiry Filter: GET /documents?isExpiringSoon=true&expiryDays=30
    const expiryRes = await fetch(`${BASE_URL}/documents?isExpiringSoon=true&expiryDays=30`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const expiryData = await expiryRes.json();
    logTest('12. GET /documents (Expiring Soon Filter)', expiryRes.status === 200 && expiryData.data.length >= 1, expiryRes.status, { count: expiryData.data.length });

    // 13. Secure Sharing: POST /sharing/create (Password protected, 2 views, 1 hour)
    const shareRes = await fetch(`${BASE_URL}/sharing/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        documentId: docId,
        password: 'DhaSharePassword99!',
        expiresInHours: 1,
        maxUses: 2,
        allowDownload: true,
      }),
    });
    const shareData = await shareRes.json();
    const shareToken = shareData.token;
    const shareId = shareData.id;
    logTest('13. POST /sharing/create (Secure Share Setup)', shareRes.status === 201 && !!shareToken, shareRes.status, { token: shareToken, hasPassword: shareData.hasPassword });

    // 14. Public Share: POST /sharing/public/:token with correct password
    const publicRes = await fetch(`${BASE_URL}/sharing/public/${shareToken}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: 'DhaSharePassword99!' }),
    });
    const publicData = await publicRes.json();
    logTest('14. POST /sharing/public/:token (Authorized Public Access)', publicRes.status === 200 && !publicData.userId && !publicData.document?.storagePath && publicData.document?.title === 'National Aadhaar Identification Card', publicRes.status, {
      title: publicData.document?.title,
      noUserIdLeak: !publicData.userId,
      noStoragePathLeak: !publicData.document?.storagePath,
    });

    // 15. Public Download: GET /sharing/public/:token/download
    const pubDownRes = await fetch(`${BASE_URL}/sharing/public/${shareToken}/download?password=DhaSharePassword99!`);
    const pubDownBuf = await pubDownRes.arrayBuffer();
    logTest('15. GET /sharing/public/:token/download (Authorized Public Stream)', pubDownRes.status === 200 && pubDownBuf.byteLength === pdfBuffer.length, pubDownRes.status, { bytes: pubDownBuf.byteLength });

    // 16. SECURITY: Public Share with Wrong Password -> 401
    const badPassRes = await fetch(`${BASE_URL}/sharing/public/${shareToken}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: 'WrongSharePassword!' }),
    });
    logTest('16. Security: Public Share Wrong Password (401)', badPassRes.status === 401, badPassRes.status, await badPassRes.json());

    // 17. SECURITY: View Limit Exceeded (maxUses was 2, we accessed once in 14, now second access in 17a, then 3rd in 17b)
    await fetch(`${BASE_URL}/sharing/public/${shareToken}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: 'DhaSharePassword99!' }),
    });
    const exceededRes = await fetch(`${BASE_URL}/sharing/public/${shareToken}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: 'DhaSharePassword99!' }),
    });
    logTest('17. Security: View Limit Exceeded (403/410)', exceededRes.status === 403 || exceededRes.status === 410, exceededRes.status, await exceededRes.json());

    // 18. Revoke Share: POST /sharing/:id/revoke
    const revokeRes = await fetch(`${BASE_URL}/sharing/${shareId}/revoke`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    logTest('18. POST /sharing/:id/revoke', revokeRes.status === 200, revokeRes.status, await revokeRes.json());

    // 19. SECURITY: Accessing Revoked Share -> 410/404
    const revokedAccessRes = await fetch(`${BASE_URL}/sharing/public/${shareToken}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: 'DhaSharePassword99!' }),
    });
    logTest('19. Security: Revoked Share Access (410/404)', revokedAccessRes.status === 410 || revokedAccessRes.status === 404, revokedAccessRes.status, await revokedAccessRes.json());

    // 20. SECURITY: Cross-User Document Modification (User B updating User A document -> 403)
    const intruderEmail = `intruder_p2_${Date.now()}@dhavault.io`;
    const regIntruder = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: intruderEmail,
        password: 'IntruderPass999!',
        fullName: 'Unauthorized Intruder',
      }),
    });
    const intruderToken = (await regIntruder.json()).accessToken;

    const crossPatchRes = await fetch(`${BASE_URL}/documents/${docId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${intruderToken}`,
      },
      body: JSON.stringify({ title: 'Hacked Document Title' }),
    });
    logTest('20. Security: Cross-User Document Modification (403)', crossPatchRes.status === 403, crossPatchRes.status, await crossPatchRes.json());

    // 21. SECURITY: Cross-User Document Delete -> 403
    const crossDeleteRes = await fetch(`${BASE_URL}/documents/${docId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${intruderToken}` },
    });
    logTest('21. Security: Cross-User Document Deletion (403)', crossDeleteRes.status === 403, crossDeleteRes.status, await crossDeleteRes.json());

    // 22. SECURITY: Fake magic byte / spoofed mime type rejection -> 400
    const spoofedFileBody = Buffer.concat([
      Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="spoofed.pdf"\r\nContent-Type: application/pdf\r\n\r\nThisIsNotAPdfHeaderItIsPlainMaliciousText`),
      postEnd,
    ]);
    const spoofedRes = await fetch(`${BASE_URL}/documents/upload`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body: spoofedFileBody,
    });
    logTest('22. Security: Spoofed PDF Magic Bytes (400)', spoofedRes.status === 400, spoofedRes.status, await spoofedRes.json());

    // 23. SECURITY: Missing / Expired JWT -> 401
    const noJwtRes = await fetch(`${BASE_URL}/documents/${docId}`);
    logTest('23. Security: Missing JWT Authentication (401)', noJwtRes.status === 401, noJwtRes.status, await noJwtRes.json());

    // 24. Clean Deletion: DELETE /documents/:id by owner
    const delRes = await fetch(`${BASE_URL}/documents/${docId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    logTest('24. DELETE /documents/:id (Owner Purge)', delRes.status === 200, delRes.status, await delRes.json());

    console.log('\n==============================================');
    console.log(`TOTAL PHASE 2 TESTS: ${results.length}`);
    const passed = results.filter((r) => r.passed).length;
    console.log(`PASSED: ${passed} / ${results.length}`);
    console.log('==============================================\n');

    fs.writeFileSync(
      path.join(__dirname, 'phase-2-test-results.json'),
      JSON.stringify(results, null, 2)
    );
  } catch (err) {
    console.error('Phase 2 test execution failed:', err);
  }
}

runPhase2Tests();
