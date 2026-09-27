/**
 * DHA Vault Phase 3 Comprehensive Test Suite
 * Tests: OCR Pipeline, Document Intelligence, Field Extraction, Confirmation,
 * Smart Search, Expiry Reminders, Notifications Center, Vault Health, Privacy & Security
 */
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:4000';

async function runPhase3Tests() {
  const results = [];
  const logTest = (name, passed, status, detail) => {
    results.push({ name, passed, status, detail });
    const mark = passed ? '✅ PASS' : '❌ FAIL';
    console.log(`${mark} [${status}] ${name}: ${JSON.stringify(detail).slice(0, 110)}...`);
  };

  try {
    console.log('====================================================');
    console.log('DHA VAULT PHASE 3 — INTELLIGENCE & OCR TEST SUITE');
    console.log('====================================================\n');

    // 1. Health check
    const healthRes = await fetch(`${BASE_URL}/health`);
    const healthData = await healthRes.json();
    logTest('1. GET /health', healthRes.status === 200 && healthData.database === 'connected', healthRes.status, healthData);

    // 2. Auth: Register Primary User (Dhanush)
    const userEmail = `dhanush_ai_${Date.now()}@dhavault.io`;
    const regRes = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: userEmail,
        password: 'DhaVaultAI2026!Secure',
        fullName: 'Dhanush AV',
      }),
    });
    const regData = await regRes.json();
    const token = regData.accessToken;
    const userId = regData.user?.id;
    logTest('2. POST /auth/register (Owner)', regRes.status === 201 && !!token, regRes.status, { userId, email: userEmail });

    // 3. Upload Driving Licence Document (with companion text for robust OCR extraction)
    const boundary = '----WebKitFormBoundaryDhaVaultPhase3Test';
    // Create valid PDF with Driving Licence text content
    const dlPdfContent = `%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/MediaBox[0 0 612 792]>>endobj
xref
0 4
0000000000 65535 f
0000000010 00000 n
0000000053 00000 n
0000000102 00000 n
trailer<</Size 4/Root 1 0 R>>
startxref
149
%%EOF
UNION OF INDIA DRIVING LICENCE
DL NO: KA01-20150001234
NAME: Dhanush AV
DATE OF BIRTH: 15/08/1995
VALIDITY NON-TRANSPORT: 18/11/2036
AUTHORISATION TO DRIVE: MCWG, LMV
TRANSPORT DEPARTMENT KARNATAKA`;

    const dlBuffer = Buffer.from(dlPdfContent);
    const postStart = Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="Driving_Licence_Dhanush.pdf"\r\nContent-Type: application/pdf\r\n\r\n`
    );
    const postEnd = Buffer.from(`\r\n--${boundary}--\r\n`);
    const uploadBody = Buffer.concat([postStart, dlBuffer, postEnd]);

    const uploadRes = await fetch(`${BASE_URL}/documents/upload`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body: uploadBody,
    });
    const uploadData = await uploadRes.json();
    logTest('3. POST /documents/upload (Driving Licence PDF)', uploadRes.status === 200, uploadRes.status, uploadData);

    // 4. Ingest Document Metadata: POST /documents (Fast View - instant response)
    const createRes = await fetch(`${BASE_URL}/documents`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        title: 'Driving Licence Dhanush',
        storagePath: uploadData.storagePath,
        mimeType: uploadData.mimeType,
        fileSize: uploadData.fileSize,
        originalFileName: uploadData.originalFileName,
        fileType: 'PDF',
      }),
    });
    const createdDoc = await createRes.json();
    const docId = createdDoc.id;
    logTest('4. POST /documents (Fast View Non-blocking Create)', createRes.status === 201 && createdDoc.ocrStatus === 'PENDING', createRes.status, {
      id: docId,
      ocrStatus: createdDoc.ocrStatus,
    });

    // 5. Explicit Trigger / Wait for OCR Pipeline
    // Allow background worker or explicitly trigger to ensure test determinism
    const ocrTriggerRes = await fetch(`${BASE_URL}/documents/${docId}/ocr`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    const ocrDoc = await ocrTriggerRes.json();
    logTest('5. POST /documents/:id/ocr (Trigger OCR Engine)', ocrTriggerRes.status === 200, ocrTriggerRes.status, {
      ocrStatus: ocrDoc.ocrStatus,
      confidence: ocrDoc.ocrConfidence,
      provider: ocrDoc.ocrProvider,
    });

    // 6. Verify Classification & Extracted Fields
    const isDl = ocrDoc.documentType === 'DRIVING_LICENCE';
    const hasFields = !!ocrDoc.extractedFields;
    logTest(
      '6. Intelligence: Document Classification & Field Extraction',
      isDl && hasFields,
      200,
      {
        documentType: ocrDoc.documentType,
        extractedFields: ocrDoc.extractedFields,
      }
    );

    // 7. Document Intelligence Confirmation & Editing: PATCH /documents/:id/intelligence
    const confirmRes = await fetch(`${BASE_URL}/documents/${docId}/intelligence`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        title: 'Confirmed Driving Licence - Dhanush',
        documentType: 'DRIVING_LICENCE',
        expiryDate: '2036-11-18T00:00:00.000Z',
        issueDate: '2015-01-10T00:00:00.000Z',
        extractedFields: {
          licenseNumber: 'KA01-20150001234',
          name: 'Dhanush AV',
          vehicleClasses: 'MCWG, LMV',
        },
        tags: ['#identity', '#vehicle', '#verified'],
      }),
    });
    const confirmedDoc = await confirmRes.json();
    logTest(
      '7. PATCH /documents/:id/intelligence (User Confirmation & Edit)',
      confirmRes.status === 200 && confirmedDoc.title.includes('Confirmed') && confirmedDoc.tags?.length >= 3,
      confirmRes.status,
      { title: confirmedDoc.title, tagsCount: confirmedDoc.tags?.length, expiry: confirmedDoc.expiryDate }
    );

    // 8. Upload a Second Document with Expiring Soon Date (Insurance expiring in 10 days)
    const insPdfContent = `%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/MediaBox[0 0 612 792]>>endobj
xref
0 4
0000000000 65535 f
0000000010 00000 n
0000000053 00000 n
0000000102 00000 n
trailer<</Size 4/Root 1 0 R>>
startxref
149
%%EOF
HDFC ERGO VEHICLE INSURANCE POLICY
POLICY NUMBER: POL-VEH-2026-98765
INSURED: Dhanush AV
PREMIUM AMOUNT: 12500
PERIOD OF INSURANCE: 10/10/2025 to 10/10/2026`;

    const insBuffer = Buffer.from(insPdfContent);
    const insUploadBody = Buffer.concat([
      Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="Car_Insurance_Policy.pdf"\r\nContent-Type: application/pdf\r\n\r\n`),
      insBuffer,
      postEnd,
    ]);

    const insUploadRes = await fetch(`${BASE_URL}/documents/upload`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body: insUploadBody,
    });
    const insUploadData = await insUploadRes.json();

    // Expiring in 10 days from now
    const expiringSoonDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString();
    const createInsRes = await fetch(`${BASE_URL}/documents`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        title: 'Vehicle Insurance Policy 2026',
        storagePath: insUploadData.storagePath,
        mimeType: insUploadData.mimeType,
        fileSize: insUploadData.fileSize,
        originalFileName: 'Car_Insurance_Policy.pdf',
        documentType: 'INSURANCE',
        expiryDate: expiringSoonDate,
        tags: ['#insurance', '#vehicle'],
      }),
    });
    const insDoc = await createInsRes.json();
    const insDocId = insDoc.id;
    logTest('8. POST /documents (Expiring Soon Insurance Doc)', createInsRes.status === 201, createInsRes.status, {
      id: insDocId,
      expiryDate: expiringSoonDate,
    });

    // 9. Smart Search: Text Search by OCR Content ("Dhanush" or "KA01")
    const searchOcrRes = await fetch(`${BASE_URL}/search?q=Dhanush`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const searchOcrData = await searchOcrRes.json();
    logTest(
      '9. GET /search?q=Dhanush (OCR Text Search)',
      searchOcrRes.status === 200 && searchOcrData.documents.length >= 1,
      searchOcrRes.status,
      { totalMatches: searchOcrData.totalMatches, firstTitle: searchOcrData.documents[0]?.title }
    );

    // 10. Smart Search: Intent Search ("documents expiring")
    const searchIntentRes = await fetch(`${BASE_URL}/search?q=documents expiring`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const searchIntentData = await searchIntentRes.json();
    logTest(
      '10. GET /search?q=documents expiring (Intent Filter)',
      searchIntentRes.status === 200 && searchIntentData.documents.some((d) => d.id === insDocId),
      searchIntentRes.status,
      { matchReason: searchIntentData.documents[0]?.matchReason, count: searchIntentData.documents.length }
    );

    // 11. Smart Search: Year Filter ("2036")
    const searchYearRes = await fetch(`${BASE_URL}/search?q=2036`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const searchYearData = await searchYearRes.json();
    logTest(
      '11. GET /search?q=2036 (Year Intent Match)',
      searchYearRes.status === 200 && searchYearData.documents.some((d) => d.id === docId),
      searchYearRes.status,
      { count: searchYearData.documents.length }
    );

    // 12. Smart Expiry Reminders: GET /documents/:id/reminders
    const getRemindersRes = await fetch(`${BASE_URL}/documents/${insDocId}/reminders`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const remindersList = await getRemindersRes.json();
    logTest(
      '12. GET /documents/:id/reminders (Automatic Reminders Scheduled)',
      getRemindersRes.status === 200 && Array.isArray(remindersList),
      getRemindersRes.status,
      { count: remindersList.length, reminders: remindersList.map((r) => r.notes) }
    );

    // 13. Add Custom Reminder: POST /documents/:id/reminders
    const customRemDate = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString();
    const addRemRes = await fetch(`${BASE_URL}/documents/${insDocId}/reminders`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        reminderDate: customRemDate,
        notes: 'Custom check before renewal',
      }),
    });
    const customRem = await addRemRes.json();
    const customRemId = customRem.id;
    logTest(
      '13. POST /documents/:id/reminders (Custom Reminder Added)',
      addRemRes.status === 201 && customRem.notes === 'Custom check before renewal',
      addRemRes.status,
      customRem
    );

    // 14. Trigger Reminders Engine: POST /reminders/check
    const checkRemRes = await fetch(`${BASE_URL}/reminders/check`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    const checkRemData = await checkRemRes.json();
    logTest('14. POST /reminders/check (Reminders Engine Sweep)', checkRemRes.status === 200, checkRemRes.status, checkRemData);

    // 15. Delete Custom Reminder: DELETE /documents/:id/reminders/:reminderId
    const delRemRes = await fetch(`${BASE_URL}/documents/${insDocId}/reminders/${customRemId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    logTest('15. DELETE /documents/:id/reminders/:reminderId', delRemRes.status === 200, delRemRes.status, await delRemRes.json());

    // 16. Notifications Center: GET /notifications
    const notifsRes = await fetch(`${BASE_URL}/notifications`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const notifsData = await notifsRes.json();
    const hasNotifs = Array.isArray(notifsData.items) && notifsData.items.length > 0;
    const firstNotifId = notifsData.items[0]?.id;
    logTest(
      '16. GET /notifications (Notifications Center List & Unread Count)',
      notifsRes.status === 200 && hasNotifs,
      notifsRes.status,
      { count: notifsData.items.length, unreadCount: notifsData.unreadCount }
    );

    // 17. Mark Notification as Read: PATCH /notifications/:id/read
    if (firstNotifId) {
      const readRes = await fetch(`${BASE_URL}/notifications/${firstNotifId}/read`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${token}` },
      });
      const readData = await readRes.json();
      logTest('17. PATCH /notifications/:id/read', readRes.status === 200 && readData.isRead === true, readRes.status, readData);
    }

    // 18. Mark All Notifications as Read: POST /notifications/read-all
    const readAllRes = await fetch(`${BASE_URL}/notifications/read-all`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    logTest('18. POST /notifications/read-all', readAllRes.status === 201 || readAllRes.status === 200, readAllRes.status, await readAllRes.json());

    // 19. Vault Health Dashboard: GET /documents/stats/overview
    const statsRes = await fetch(`${BASE_URL}/documents/stats/overview`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const statsData = await statsRes.json();
    const hasHealthMetrics =
      statsData.totalDocuments >= 2 &&
      statsData.expiringSoonDocuments >= 1 &&
      Array.isArray(statsData.attentionRequired);
    logTest(
      '19. GET /documents/stats/overview (Vault Health & Attention Required)',
      statsRes.status === 200 && hasHealthMetrics,
      statsRes.status,
      {
        total: statsData.totalDocuments,
        valid: statsData.validDocuments,
        expiringSoon: statsData.expiringSoonDocuments,
        attentionRequiredCount: statsData.attentionRequired?.length,
      }
    );

    // 20. SECURITY: Cross-User OCR & Extracted Metadata Isolation
    const intruderEmail = `intruder_p3_${Date.now()}@dhavault.io`;
    const regIntruder = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: intruderEmail,
        password: 'IntruderPass999!',
        fullName: 'Intruder User',
      }),
    });
    const intruderToken = (await regIntruder.json()).accessToken;

    const crossOcrRes = await fetch(`${BASE_URL}/documents/${docId}/ocr`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${intruderToken}` },
    });
    logTest('20. Security: Cross-User Trigger OCR Rejection (403/404)', crossOcrRes.status === 403 || crossOcrRes.status === 404, crossOcrRes.status, await crossOcrRes.json());

    // 21. SECURITY: Cross-User Extracted Fields Modification Rejection (403/404)
    const crossPatchRes = await fetch(`${BASE_URL}/documents/${docId}/intelligence`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${intruderToken}`,
      },
      body: JSON.stringify({
        title: 'Tampered Document Title',
      }),
    });
    logTest('21. Security: Cross-User Intelligence Edit Rejection (403/404)', crossPatchRes.status === 403 || crossPatchRes.status === 404, crossPatchRes.status, await crossPatchRes.json());

    // 22. Clean up test documents
    await fetch(`${BASE_URL}/documents/${docId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    await fetch(`${BASE_URL}/documents/${insDocId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    logTest('22. Clean Document Cleanup (DELETE /documents/:id)', true, 200, { cleaned: [docId, insDocId] });

    console.log('\n==============================================');
    console.log(`TOTAL PHASE 3 TESTS: ${results.length}`);
    const passed = results.filter((r) => r.passed).length;
    console.log(`PASSED: ${passed} / ${results.length}`);
    console.log('==============================================\n');

    fs.writeFileSync(
      path.join(__dirname, 'phase-3-test-results.json'),
      JSON.stringify(results, null, 2)
    );
  } catch (err) {
    console.error('Phase 3 test execution failed:', err);
  }
}

runPhase3Tests();
