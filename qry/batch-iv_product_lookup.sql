SELECT DISTINCT
	ENCOUNTER.ENCNTR_ID,
	pi_get_cv_display(ENCOUNTER.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
	ORDER_PRODUCT.ITEM_ID,
	pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS MEDICATION,
	MED_IDENTIFIER.VALUE AS MED_PRODUCT
FROM
	CE_MED_RESULT,
	CLINICAL_EVENT,
	ENCOUNTER,
	MED_IDENTIFIER,
	ORDER_PRODUCT
WHERE
	CLINICAL_EVENT.EVENT_CD IN (
		37556889 -- esmolol
		--37557367, -- ketamine
		--37557675, -- niCARdipine
		--37558323 -- vasopressin
	)
	AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN
		pi_to_gmt(SYSDATE - 1, pi_time_zone(2, @Variable('BOUSER')))
		AND pi_to_gmt(SYSDATE, pi_time_zone(2, @Variable('BOUSER')))
	AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
	AND CE_MED_RESULT.IV_EVENT_CD > 0
	AND CLINICAL_EVENT.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
	AND ENCOUNTER.LOC_FACILITY_CD IN (
		3310, -- HH HERMANN
		3796, -- HC Childrens
		3821, -- HH Clinics
		3822, -- HH Trans Care
		3823 -- HH Rehab		
	)
	AND CLINICAL_EVENT.ORDER_ID = ORDER_PRODUCT.ORDER_ID
	/*
	AND ORDER_PRODUCT.ITEM_ID IN (
		275733495, -- ketAMINE 10 mg/mL in NS 50 mL syringe
		3639548, -- esmolol 2500 mg-NS 250 ml premix
		234040263, -- esmolol 2500 mg/H20 250 mL Premix
		89066190, -- niCARdipine 20mg/NS 200ml IV Soln
		89066350, -- niCARdipine 40 mg/ NS 200 ml IV Soln (premix)
		245273967 -- vasopressin 0.2 unit/mL (20 unit/100 mL) INJ
	) 
	*/
	AND ORDER_PRODUCT.ITEM_ID = MED_IDENTIFIER.ITEM_ID
	AND MED_IDENTIFIER.MED_IDENTIFIER_TYPE_CD = 1564 -- Description
	AND MED_IDENTIFIER.MED_PRODUCT_ID = 0