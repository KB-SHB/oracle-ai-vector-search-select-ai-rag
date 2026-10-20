-- Run as SUPPORT_AI. Synthetic data only (no real customer data in a portfolio repo).

INSERT INTO product VALUES (1,'Nimbus Billing');
INSERT INTO product VALUES (2,'Nimbus Inventory');
INSERT INTO product VALUES (3,'Nimbus Analytics');
INSERT INTO product VALUES (4,'Nimbus Platform');

INSERT INTO kb_article(article_id,product_id,title,body) VALUES (1,1,'Invoice PDF fails to generate',
q'[If an invoice PDF fails to generate, first check that the customer logo file is under 2 MB and saved as PNG or JPEG. Oversized or corrupt logos make the rendering service time out. Next, confirm the invoice template has no empty required fields. Open Settings, Templates, and run Validate. If validation passes but rendering still fails, clear the template cache and regenerate. Persistent failures should be escalated with the invoice number and the rendering request ID from the error banner.]');
INSERT INTO kb_article(article_id,product_id,title,body) VALUES (2,1,'Customer was charged twice: duplicate payment refund',
q'[A duplicate charge usually happens when a customer double-clicks the pay button or the payment gateway retries after a timeout. Locate both transactions in Payments, Transaction Log. Verify the gateway reference IDs differ. Issue a refund for the second transaction only. Refunds to cards take 5 to 10 business days to appear. Always add an internal note with both reference IDs so Finance can reconcile at month end.]');
INSERT INTO kb_article(article_id,product_id,title,body) VALUES (3,1,'VAT not applied to EU customer invoices',
q'[When VAT is missing on invoices for European customers, check the customer billing country and the VAT registration number. B2B customers with a valid VAT ID may be reverse-charged, which shows zero VAT by design. For consumers, ensure the tax region mapping includes the destination country. Update tax rules under Settings, Tax, then regenerate the affected invoices as credit note plus new invoice rather than editing issued documents.]');
INSERT INTO kb_article(article_id,product_id,title,body) VALUES (4,2,'Stock counts differ after warehouse sync',
q'[If quantities in the system differ from the warehouse after a sync, look for transfers stuck in Pending status. Pending transfers reserve stock at the source but have not yet arrived at the destination. Check the sync log for failed batches and re-run the failed batch. Do not adjust quantities manually until pending transfers are cleared, otherwise the adjustment will be double counted on the next sync.]');
INSERT INTO kb_article(article_id,product_id,title,body) VALUES (5,2,'Handheld barcode scanner is not recognized',
q'[When a handheld scanner is not recognized, confirm it is set to keyboard emulation mode (HID) and not serial mode. Scan the configuration barcode from the scanner manual to reset it. Test in a plain text field first. If the scanner types but the app ignores input, enable Scanner Input under Device Settings and make sure the cursor focus is in the item lookup field. Replace the cable before replacing the device.]');
INSERT INTO kb_article(article_id,product_id,title,body) VALUES (6,2,'Low-stock alert emails are not sent',
q'[Low-stock notifications depend on the reorder point being set on each item and on at least one active recipient in the alert group. Check that the alert rule is enabled and that the recipient address is verified. Alerts are evaluated nightly at 02:00 UTC, so a stock drop during the day will only notify the next morning. Check the spam folder and add the sender domain to the allow list.]');
INSERT INTO kb_article(article_id,product_id,title,body) VALUES (7,3,'Dashboards load slowly',
q'[Slow dashboards are typically caused by too many widgets querying large date ranges. Limit the default date filter to 30 days, remove unused widgets, and enable cached results for widgets that do not need real-time data. For very large datasets, ask an administrator to create a summary table refreshed nightly. Browser extensions that block scripts can also slow rendering, so test in a private window.]');
INSERT INTO kb_article(article_id,product_id,title,body) VALUES (8,3,'Scheduled report email did not arrive',
q'[If a scheduled report was not delivered, open Reports, Schedules, and check the last run status. A failed run shows the error reason. Common causes are an expired recipient address, an attachment larger than 20 MB, or a schedule paused after three consecutive failures. Reduce the attachment size by exporting to CSV or sending a link instead, then resume the schedule.]');
INSERT INTO kb_article(article_id,product_id,title,body) VALUES (9,3,'Data refresh fails with credential error',
q'[A data refresh that fails with an authentication or credential error normally means the stored connection password or API token has expired or been rotated. Edit the data source, re-enter the credential, and press Test Connection. If the source uses OAuth, re-authorize the connection. After a successful test, trigger a manual refresh. Use a service account with a non-expiring secret to prevent this recurring.]');
INSERT INTO kb_article(article_id,product_id,title,body) VALUES (10,4,'Single sign-on redirect loop',
q'[A login redirect loop with SSO is most often a mismatch between the identity provider reply URL and the application URL, or a clock skew above five minutes between the two systems. Verify the assertion consumer URL exactly matches, including the trailing slash. Check that server time is synchronized with NTP. Clear browser cookies for both domains before retesting. Capture a SAML trace if the loop persists.]');

-- Synthetic tickets: paraphrased on purpose so keyword search alone struggles.
INSERT INTO ticket (product_id,severity,status,subject,description,created_at,resolved_article_id)
SELECT p.product_id,
       CASE WHEN p.sev < .1 THEN 'CRITICAL' WHEN p.sev < .35 THEN 'HIGH' WHEN p.sev < .7 THEN 'MEDIUM' ELSE 'LOW' END,
       CASE WHEN p.st < .5 THEN 'RESOLVED' WHEN p.st < .75 THEN 'IN_PROGRESS' ELSE 'OPEN' END,
       p.subject, p.descr,
       SYSTIMESTAMP - NUMTODSINTERVAL(p.age, 'DAY'),
       CASE WHEN p.st < .5 THEN p.article_id END
FROM (
  SELECT ROWNUM rn, t.product_id, t.subject, t.descr, t.article_id,
         DBMS_RANDOM.VALUE sev, DBMS_RANDOM.VALUE st, DBMS_RANDOM.VALUE(0,90) age
  FROM (SELECT LEVEL lv FROM dual CONNECT BY LEVEL <= 300) n
  JOIN (
    SELECT 0 idx,1 product_id,1 article_id,'Cannot download invoice' subject,'Clicking print invoice just spins and then errors out. Our logo is a big image.' descr FROM dual UNION ALL
    SELECT 1,1,2,'Client billed two times','Customer says the card was hit twice for the same order, please sort it out.' FROM dual UNION ALL
    SELECT 2,1,3,'No tax on German invoice','Invoices going to our Berlin clients show no tax line at all.' FROM dual UNION ALL
    SELECT 3,2,4,'Inventory numbers wrong','The numbers on screen do not match what the warehouse counted after last night.' FROM dual UNION ALL
    SELECT 4,2,5,'Scanner does nothing','New handheld gun beeps but nothing shows up in the app.' FROM dual UNION ALL
    SELECT 5,2,6,'Never warned about running out','We ran out of an item and nobody got an email.' FROM dual UNION ALL
    SELECT 6,3,7,'Dashboard takes forever','Main dashboard needs about a minute to open every morning.' FROM dual UNION ALL
    SELECT 7,3,8,'Weekly report missing','The Monday report stopped showing up in the managers inbox.' FROM dual UNION ALL
    SELECT 8,3,9,'Refresh keeps failing','Nightly data load says login failed since the DB password was changed.' FROM dual UNION ALL
    SELECT 9,4,10,'Cannot log in with company account','After entering SSO credentials the page bounces back and forth endlessly.' FROM dual
  ) t ON t.idx = MOD(n.lv,10)
) p;

-- Golden questions (paraphrased, so they test semantic retrieval)
INSERT INTO golden_question(question,expected_article_id) VALUES ('Why does printing an invoice time out when the company logo is huge?',1);
INSERT INTO golden_question(question,expected_article_id) VALUES ('A shopper was billed two times for one order, how do I give the money back?',2);
INSERT INTO golden_question(question,expected_article_id) VALUES ('Our clients in Europe get invoices without any tax line',3);
INSERT INTO golden_question(question,expected_article_id) VALUES ('Warehouse count disagrees with the system after synchronisation',4);
INSERT INTO golden_question(question,expected_article_id) VALUES ('The handheld gun beeps but the app ignores what it scans',5);
INSERT INTO golden_question(question,expected_article_id) VALUES ('Why did nobody get notified that we were running out of an item?',6);
INSERT INTO golden_question(question,expected_article_id) VALUES ('Main dashboard is very sluggish to open',7);
INSERT INTO golden_question(question,expected_article_id) VALUES ('Managers stopped receiving the weekly automated report',8);
INSERT INTO golden_question(question,expected_article_id) VALUES ('Nightly load fails with login failed after we changed the database password',9);
INSERT INTO golden_question(question,expected_article_id) VALUES ('Company login keeps bouncing between two pages',10);
COMMIT;
