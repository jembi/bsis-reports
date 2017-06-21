# ADD VIEW TO GENERATE DONATION SUMMARY
# ---------------------------------------------
CREATE OR REPLACE VIEW `donationSummaryView` AS
SELECT
donationIdentificationNumber, donorNumber, gender, TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) as age,
CASE
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 16 AND 25 THEN '16-25'
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 26 AND 35 THEN '26-35'
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 36 AND 50 THEN '36-50'
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 51 AND 65 THEN '51-65'
ELSE 'Other'
END AS ageGroup,
donationDate, Location.name as venue, donationType, packType,
CONCAT(Donation.bloodAbo, Donation.bloodRh) as bloodType, bleedStartTime, bleedEndTime,
bloodTypingStatus, bloodTypingMatchStatus, ttiStatus,
donorWeight, haemoglobinCount, haemoglobinLevel, donorPulse,  bloodPressureSystolic, bloodPressureDiastolic,
adverseEvent_id, ineligibleDonor, released, flaggedForCounselling, counsellingStatus, counsellingDate,

CASE
WHEN counsellingStatus = 'RECEIVED_COUNSELLING' THEN 'Counselled'
WHEN counsellingStatus = 'REFUSED_COUNSELLING' THEN 'Refused Counselling'
ELSE 'Not Counselled'
END AS donorCounsellingStatus,

CASE
WHEN ttiStatus = 'TTI_UNSAFE' AND released = '1'
	AND (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS') THEN 'Reactive for HIV'
WHEN ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'Reactive for Other TTIs'
WHEN ttiStatus = 'TTI_SAFE' AND released = '1' THEN 'TTI Unreactive'
ELSE 'Unknown'
END AS ttiReactiveStatus

FROM Donation
LEFT JOIN Donor ON Donation.donor_id = Donor.id
LEFT JOIN Location ON Donation.venue_id = Location.id
LEFT JOIN DonationType ON Donation.donationType_id = DonationType.id
LEFT JOIN PackType ON Donation.packType_id = PackType.id
LEFT JOIN PostDonationCounselling ON Donation.id = PostDonationCounselling.donation_id
LEFT JOIN BloodTestResult testHIVRepeat1 ON testHIVRepeat1.donation_id = Donation.id AND testHIVRepeat1.bloodTest_id = 18 AND testHIVRepeat1.isDeleted = 0
LEFT JOIN BloodTestResult testHIVRepeat2 ON testHIVRepeat2.donation_id = Donation.id AND testHIVRepeat2.bloodTest_id = 19 AND testHIVRepeat2.isDeleted = 0

WHERE Donation.isDeleted = 0
AND Donor.isDeleted = 0
AND Donor.donorStatus != 'MERGED'
AND PackType.countAsDonation = 1
GROUP BY donationIdentificationNumber
ORDER BY donationDate;

# ADD VIEW TO GENERATE COMPONENT BATCH LOCATION
# ---------------------------------------------
CREATE OR REPLACE VIEW `componentBatchLocationView` AS
SELECT ComponentBatch.id, Location.name FROM ComponentBatch, Location WHERE ComponentBatch.location_id = Location.id;

# ADD VIEW TO GENERATE INVENTORY SUMMARY
# ---------------------------------------------
CREATE OR REPLACE VIEW `inventorySummaryView` AS
SELECT
donationIdentificationNumber, ComponentType.componentTypeName, componentCode,
createdOn, componentBatchLocationView.name as 'processedAtLocation',
Location.name as 'currentLocation', IF(TIMESTAMPDIFF(DAY,expiresOn,CURDATE()) >0,'EXPIRED','NOT EXPIRED') as 'expiryStatus',
Component.status AS componentStatus,inventoryStatus, ReturnForm.status as returnStatus,
CASE
WHEN Component.status = 'PROCESSED' THEN 'Processed'
WHEN Component.status = 'EXPIRED' THEN 'Expired'
WHEN Component.status = 'DISCARDED' THEN 'Discarded'
WHEN Component.status = 'ISSUED' THEN 'Issued'
WHEN Component.status = 'TRANSFUSED' THEN 'Transfused'
ELSE 'Other States'
END AS finalComponentStatus
FROM Component
LEFT JOIN Donation ON Component.donation_id = Donation.id
LEFT JOIN ComponentType ON Component.componentType_id = ComponentType.id
LEFT JOIN ComponentType ParentComponentType ON Component.parentComponent_id = ParentComponentType.id
LEFT JOIN Location ON Component.location_id = Location.id
LEFT JOIN ComponentBatch ON Component.componentBatch_id = ComponentBatch.id
LEFT JOIN componentBatchLocationView ON Component.componentBatch_id = componentBatchLocationView.id
LEFT JOIN ReturnForm_Component ON Component.id = ReturnForm_Component.component_id
LEFT JOIN ReturnForm ON ReturnForm_Component.returnForm_id = ReturnForm.id
WHERE Component.isDeleted = '0'
ORDER BY donationIdentificationNumber, componentCode;

# ADD VIEW TO GENERATE DEFERRAL SUMMARY
# ---------------------------------------------
CREATE OR REPLACE VIEW `deferralSummaryView` AS
SELECT donorNumber, gender,

CASE
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 16 AND 25 THEN '16-25'
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 26 AND 35 THEN '26-35'
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 36 AND 50 THEN '36-50'
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 51 AND 65 THEN '51-65'
ELSE 'Other'
END AS ageGroup,

deferralDate, reason, Location.name AS 'venue'
FROM bsis.DonorDeferral
LEFT JOIN DeferralReason ON DonorDeferral.deferralReason_id = DeferralReason.id
LEFT JOIN Location ON DonorDeferral.venue_id = Location.id
LEFT JOIN Donor ON DonorDeferral.deferredDonor_id = Donor.id
WHERE DonorDeferral.isVoided = '0' AND Donor.isDeleted = '0'
ORDER BY deferralDate;

# ADD VIEW TO GENERATE DISCARD SUMMARY
# ---------------------------------------------
CREATE OR REPLACE VIEW `discardSummaryView` AS
SELECT statusChangedOn, statusChangeReason, componentTypeName, componentBatchLocationView.name as 'processedAtLocation'
FROM bsis.ComponentStatusChange
LEFT JOIN Component ON ComponentStatusChange.component_id = Component.id
LEFT JOIN ComponentType ON Component.componentType_id = ComponentType.id
LEFT JOIN ComponentStatusChangeReason ON ComponentStatusChange.statusChangeReason_id = ComponentStatusChangeReason.id
LEFT JOIN ComponentBatch ON Component.componentBatch_id = ComponentBatch.id
LEFT JOIN componentBatchLocationView ON Component.componentBatch_id = componentBatchLocationView.id
WHERE newStatus = 'DISCARDED'
AND Component.isDeleted = '0'
AND ComponentStatusChange.isDeleted = '0';

# ADD VIEW TO GENERATE ISSUED SUMMARY
# ---------------------------------------------
CREATE OR REPLACE VIEW `issuedSummaryView` AS
SELECT
OrderForm.id as 'orderId',

CASE
WHEN OrderForm.status = 'CREATED' THEN 'Order not Dispatched'
WHEN OrderForm.status = 'DISPATCHED' THEN 'Issued'
ELSE 'Unknown'
END AS orderStatus,

orderDate,  DispatchedTo.name as 'dispatchedTo',
componentTypeName
FROM OrderForm_Component
LEFT JOIN OrderForm ON OrderForm_Component.orderForm_id = OrderForm.id
LEFT JOIN Component ON OrderForm_Component.component_id = Component.id
LEFT JOIN ComponentType ON Component.componentType_id = ComponentType.id
LEFT JOIN Location DispatchedTo ON OrderForm.dispatchedTo_id = DispatchedTo.id
WHERE OrderForm.isDeleted = '0'
AND type = "ISSUE"
AND OrderForm.status = "DISPATCHED"
AND Component.isDeleted = 0
ORDER BY orderId;


# ADD VIEW TO GENERATE TESTING SUMMARY
# ---------------------------------------------
CREATE OR REPLACE VIEW `testingSummaryView` AS
SELECT
donationIdentificationNumber, donorNumber, gender, TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) as age,
CASE
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 16 AND 25 THEN '16-25'
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 26 AND 35 THEN '26-35'
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 36 AND 50 THEN '36-50'
WHEN TIMESTAMPDIFF(YEAR,birthDate,CURDATE()) BETWEEN 51 AND 65 THEN '51-65'
ELSE 'Other'
END AS ageGroup,
donationDate, Location.name as venue, donationType, packType,
CONCAT(Donation.bloodAbo, Donation.bloodRh) as bloodType, bleedStartTime, bleedEndTime,
bloodTypingStatus, bloodTypingMatchStatus, ttiStatus,
adverseEvent_id, ineligibleDonor, released,

CASE
WHEN CONCAT(Donation.bloodAbo, Donation.bloodRh) = 'O+' AND bloodTypingMatchStatus IN ('MATCH','RESOLVED') THEN ' O+'
WHEN CONCAT(Donation.bloodAbo, Donation.bloodRh) = 'O-' AND bloodTypingMatchStatus IN ('MATCH','RESOLVED') THEN ' O-'
WHEN CONCAT(Donation.bloodAbo, Donation.bloodRh) = 'A+' AND bloodTypingMatchStatus IN ('MATCH','RESOLVED') THEN ' A+'
WHEN CONCAT(Donation.bloodAbo, Donation.bloodRh) = 'A-' AND bloodTypingMatchStatus IN ('MATCH','RESOLVED') THEN ' A-'
WHEN CONCAT(Donation.bloodAbo, Donation.bloodRh) = 'B+' AND bloodTypingMatchStatus IN ('MATCH','RESOLVED') THEN ' B+'
WHEN CONCAT(Donation.bloodAbo, Donation.bloodRh) = 'B-' AND bloodTypingMatchStatus IN ('MATCH','RESOLVED') THEN ' B-'
WHEN CONCAT(Donation.bloodAbo, Donation.bloodRh) = 'AB+' AND bloodTypingMatchStatus IN ('MATCH','RESOLVED') THEN ' AB+'
WHEN CONCAT(Donation.bloodAbo, Donation.bloodRh) = 'AB-' AND bloodTypingMatchStatus IN ('MATCH','RESOLVED') THEN ' AB-'
WHEN bloodTypingMatchStatus = 'NO_TYPE_DETERMINED' THEN 'No Type Determined'
ELSE 'Unknown'
END AS bloodGrouping,

CASE
WHEN (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'Reactive for HIV'
WHEN released = '1' THEN 'Not Reactive for HIV'
ELSE 'Unknown'
END AS hivPrevalence,

CASE
WHEN (testHBVRepeat1.result = 'POS' OR testHBVRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'Reactive for HBV'
WHEN released = '1' THEN 'Not Reactive for HBV'
ELSE 'Unknown'
END AS hbvPrevalence,

CASE
WHEN (testHCVRepeat1.result = 'POS' OR testHCVRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'Reactive for HCV'
WHEN released = '1' THEN 'Not Reactive for HCV'
ELSE 'Unknown'
END AS hcvPrevalence,

CASE
WHEN (testSyphilisRepeat1.result = 'POS' OR testSyphilisRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'Reactive for Syphilis'
WHEN released = '1' THEN 'Not Reactive for Syphilis'
ELSE 'Unknown'
END AS syphilisPrevalence,


CASE
WHEN (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS')
	AND (testHBVRepeat1.result = 'POS' OR testHBVRepeat2.result = 'POS')
	AND (testHCVRepeat1.result = 'POS' OR testHCVRepeat2.result = 'POS')
  AND (testSyphilisRepeat1.result = 'POS' OR testSyphilisRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'HIV, HBV, HCV, Syphilis'
WHEN (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS')
	AND (testHBVRepeat1.result = 'POS' OR testHBVRepeat2.result = 'POS')
  AND (testHCVRepeat1.result = 'POS' OR testHCVRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'HIV, HBV, HCV'
WHEN (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS')
	AND (testHBVRepeat1.result = 'POS' OR testHBVRepeat2.result = 'POS')
  AND (testSyphilisRepeat1.result = 'POS' OR testSyphilisRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'HIV, HBV, Syphilis'
WHEN (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS')
	AND (testHCVRepeat1.result = 'POS' OR testHCVRepeat2.result = 'POS')
  AND (testSyphilisRepeat1.result = 'POS' OR testSyphilisRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'HIV, HCV, Syphilis'
WHEN (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS')
	AND (testHBVRepeat1.result = 'POS' OR testHBVRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'HIV, HBV'
WHEN (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS')
	AND (testHCVRepeat1.result = 'POS' OR testHCVRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'HIV, HCV'
WHEN (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS')
	AND (testSyphilisRepeat1.result = 'POS' OR testSyphilisRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'HIV, Syphilis'
WHEN  (testHIVRepeat1.result = 'POS' OR testHIVRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'HIV'
WHEN (testHBVRepeat1.result = 'POS' OR testHBVRepeat2.result = 'POS')
	OR (testHCVRepeat1.result = 'POS' OR testHCVRepeat2.result = 'POS')
  OR (testSyphilisRepeat1.result = 'POS' OR testSyphilisRepeat2.result = 'POS')
	AND ttiStatus = 'TTI_UNSAFE' AND released = '1' THEN 'Other TTIs (Excl. HIV)'
WHEN released = '1' THEN 'No TTIs'
ELSE 'Unknown'
END AS ttiCoinfection

FROM Donation
LEFT JOIN Donor ON Donation.donor_id = Donor.id
LEFT JOIN Location ON Donation.venue_id = Location.id
LEFT JOIN DonationType ON Donation.donationType_id = DonationType.id
LEFT JOIN PackType ON Donation.packType_id = PackType.id

LEFT JOIN BloodTestResult testABO ON testABO.donation_id = Donation.id AND testABO.bloodTest_id = 1 AND testABO.isDeleted = 0
LEFT JOIN BloodTestResult testRh ON testRh.donation_id = Donation.id AND testRh.bloodTest_id = 2 AND testRh.isDeleted = 0
LEFT JOIN BloodTestResult testABORepeat ON testABORepeat.donation_id = Donation.id AND testABORepeat.bloodTest_id = 34 AND testABORepeat.isDeleted = 0
LEFT JOIN BloodTestResult testRhRepeat ON testRhRepeat.donation_id = Donation.id AND testRhRepeat.bloodTest_id = 35 AND testRhRepeat.isDeleted = 0
LEFT JOIN BloodTestResult testTitre ON testTitre.donation_id = Donation.id AND testTitre.bloodTest_id = 3 AND testTitre.isDeleted = 0
LEFT JOIN BloodTestResult testAbScr ON testAbScr.donation_id = Donation.id AND testAbScr.bloodTest_id = 33 AND testAbScr.isDeleted = 0

LEFT JOIN BloodTestResult testHIV ON testHIV.donation_id = Donation.id AND testHIV.bloodTest_id = 17 AND testHIV.isDeleted = 0
LEFT JOIN BloodTestResult testHIVRepeat1 ON testHIVRepeat1.donation_id = Donation.id AND testHIVRepeat1.bloodTest_id = 18 AND testHIVRepeat1.isDeleted = 0
LEFT JOIN BloodTestResult testHIVRepeat2 ON testHIVRepeat2.donation_id = Donation.id AND testHIVRepeat2.bloodTest_id = 19 AND testHIVRepeat2.isDeleted = 0
LEFT JOIN BloodTestResult testHIVConf ON testHIVConf.donation_id = Donation.id AND testHIVConf.bloodTest_id = 29 AND testHIVConf.isDeleted = 0

LEFT JOIN BloodTestResult testHBV ON testHBV.donation_id = Donation.id AND testHBV.bloodTest_id = 20 AND testHBV.isDeleted = 0
LEFT JOIN BloodTestResult testHBVRepeat1 ON testHBVRepeat1.donation_id = Donation.id AND testHBVRepeat1.bloodTest_id = 21 AND testHBVRepeat1.isDeleted = 0
LEFT JOIN BloodTestResult testHBVRepeat2 ON testHBVRepeat2.donation_id = Donation.id AND testHBVRepeat2.bloodTest_id = 22 AND testHBVRepeat2.isDeleted = 0
LEFT JOIN BloodTestResult testHBVConf ON testHBVConf.donation_id = Donation.id AND testHBVConf.bloodTest_id = 30 AND testHBVConf.isDeleted = 0

LEFT JOIN BloodTestResult testHCV ON testHCV.donation_id = Donation.id AND testHCV.bloodTest_id = 23 AND testHCV.isDeleted = 0
LEFT JOIN BloodTestResult testHCVRepeat1 ON testHCVRepeat1.donation_id = Donation.id AND testHCVRepeat1.bloodTest_id = 24 AND testHCVRepeat1.isDeleted = 0
LEFT JOIN BloodTestResult testHCVRepeat2 ON testHCVRepeat2.donation_id = Donation.id AND testHCVRepeat2.bloodTest_id = 25 AND testHCVRepeat2.isDeleted = 0
LEFT JOIN BloodTestResult testHCVConf ON testHCVConf.donation_id = Donation.id AND testHCVConf.bloodTest_id = 31 AND testHCVConf.isDeleted = 0

LEFT JOIN BloodTestResult testSyphilis ON testSyphilis.donation_id = Donation.id AND testSyphilis.bloodTest_id = 26 AND testSyphilis.isDeleted = 0
LEFT JOIN BloodTestResult testSyphilisRepeat1 ON testSyphilisRepeat1.donation_id = Donation.id AND testSyphilisRepeat1.bloodTest_id = 27 AND testSyphilisRepeat1.isDeleted = 0
LEFT JOIN BloodTestResult testSyphilisRepeat2 ON testSyphilisRepeat2.donation_id = Donation.id AND testSyphilisRepeat2.bloodTest_id = 28 AND testSyphilisRepeat2.isDeleted = 0
LEFT JOIN BloodTestResult testSyphilisConf ON testSyphilisConf.donation_id = Donation.id AND testSyphilisConf.bloodTest_id = 32 AND testSyphilisConf.isDeleted = 0

WHERE Donation.isDeleted = 0
AND Donor.isDeleted = 0
AND Donor.donorStatus != 'MERGED'
AND PackType.countAsDonation = 1
GROUP BY donationIdentificationNumber
ORDER BY donationDate;
