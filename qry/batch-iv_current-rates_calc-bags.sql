WITH DOSES AS (
	SELECT DISTINCT
		ENCOUNTER.ENCNTR_ID,
		ENCOUNTER.PERSON_ID,
		CLINICAL_EVENT.EVENT_ID,
		CLINICAL_EVENT.ORDER_ID,
		ENCOUNTER.ARRIVE_DT_TM,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CE_MED_RESULT.ADMIN_DOSAGE,
		CE_MED_RESULT.INFUSION_RATE,
		CE_MED_RESULT.INFUSION_UNIT_CD,
		CE_MED_RESULT.IV_EVENT_CD,
		ORDER_PRODUCT.ITEM_ID,
		CLINICAL_EVENT.EVENT_CD,
		ORDER_PRODUCT.ACTION_SEQUENCE
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		ENCOUNTER,
		ORDER_PRODUCT
	WHERE
		CLINICAL_EVENT.EVENT_CD IN (
			37556889, -- esmolol
			37557367, -- ketamine
			37557675, -- niCARdipine
			37558323 -- vasopressin
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN
			pi_to_gmt(SYSDATE - 1, 'America/Chicago')
			AND pi_to_gmt(SYSDATE, 'America/Chicago')
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
		AND ORDER_PRODUCT.ITEM_ID IN (
			275733495, -- ketAMINE 10 mg/mL in NS 50 mL syringe
			2931843, -- ketAMINE 500 mg/10 ml INJ VL
			3639548, -- esmolol 2500 mg-NS 250 ml premix
			234040263, -- esmolol 2500 mg/H20 250 mL Premix
			2894335, -- esmolol 100 mg/10 ml INJ VL
			89066190, -- niCARdipine 20mg/NS 200ml IV Soln
			89066350, -- niCARdipine 40 mg/ NS 200 ml IV Soln (premix)
			245273967 -- vasopressin 0.2 unit/mL (20 unit/100 mL) INJ
		) 
), LAST_CHARTED AS (
	SELECT DISTINCT
		DOSES.ENCNTR_ID,
		DOSES.ITEM_ID,
		MAX(DOSES.EVENT_END_DT_TM) AS LAST_CHARTED_DT_TM
	FROM
		DOSES
	WHERE
		DOSES.ADMIN_DOSAGE > 0
		OR DOSES.IV_EVENT_CD IN (
			688706, -- Begin Bag
			688709 -- Rate Change
		)
	GROUP BY 
		DOSES.ENCNTR_ID,
		DOSES.ITEM_ID
), BAGS_YESTERDAY AS (
	SELECT DISTINCT
		DOSES.ENCNTR_ID,
		DOSES.EVENT_CD,
		COUNT(DOSES.EVENT_ID) AS BAGS_LAST_24H
	FROM
		DOSES
	WHERE
		DOSES.IV_EVENT_CD = 688706 -- Begin Bag
	GROUP BY 
		DOSES.ENCNTR_ID,
		DOSES.EVENT_CD
)

SELECT DISTINCT
	DOSES.EVENT_CD,
	MAX(MED_IDENTIFIER.VALUE) KEEP (DENSE_RANK LAST ORDER BY DOSES.ACTION_SEQUENCE) AS MED_PRODUCT, 
	--MED_IDENTIFIER.VALUE AS MED_PRODUCT,
	pi_get_cv_display(ENCOUNTER.LOC_NURSE_UNIT_CD) AS CURRENT_NURSE_UNIT,
	ENCNTR_ALIAS.ALIAS AS FIN,
	PERSON.NAME_FULL_FORMATTED AS NAME,
	--pi_from_gmt(MAX(DOSES.EVENT_END_DT_TM), 'America/Chicago') AS LAST_RATE_DATETIME,
	pi_from_gmt(LAST_CHARTED.LAST_CHARTED_DT_TM, 'America/Chicago') AS LAST_CHARTED_DATETIME,
	MAX(DOSES.INFUSION_RATE) KEEP (DENSE_RANK LAST ORDER BY DOSES.EVENT_END_DT_TM) AS RATE, 
	MAX(DOSES.INFUSION_UNIT_CD) KEEP (DENSE_RANK LAST ORDER BY DOSES.EVENT_END_DT_TM) AS RATE_UNIT_CD,
	pi_get_cv_display(MAX(DOSES.INFUSION_UNIT_CD) KEEP (DENSE_RANK LAST ORDER BY DOSES.EVENT_END_DT_TM)) AS RATE_UNITS,
	ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE AS WEIGHT,
	OD_WT_UNITS.OE_FIELD_DISPLAY_VALUE AS WEIGHT_UNITS,
	MED_DISPENSE.STRENGTH,
	MED_DISPENSE.STRENGTH_UNIT_CD,
	pi_get_cv_display(MED_DISPENSE.STRENGTH_UNIT_CD) AS STRENGTH_UNITS,
	MED_DISPENSE.VOLUME,
	MED_DISPENSE.VOLUME_UNIT_CD,
	pi_get_cv_display(MED_DISPENSE.VOLUME_UNIT_CD) AS VOLUME_UNITS,
	BAGS_YESTERDAY.BAGS_LAST_24H
FROM
	BAGS_YESTERDAY,
	DOSES,
	ENCNTR_ALIAS,
	ENCOUNTER,
	LAST_CHARTED,
	MED_DISPENSE,
	MED_IDENTIFIER,
	ORDER_DETAIL,
	ORDER_DETAIL OD_WT_UNITS,
	ORDERS,
	PERSON
WHERE
	DOSES.ITEM_ID = MED_IDENTIFIER.ITEM_ID
	AND MED_IDENTIFIER.MED_IDENTIFIER_TYPE_CD = 1564 -- Description
	AND MED_IDENTIFIER.MED_PRODUCT_ID = 0
	AND DOSES.ITEM_ID = MED_DISPENSE.ITEM_ID
	AND DOSES.ENCNTR_ID = LAST_CHARTED.ENCNTR_ID
	AND DOSES.ITEM_ID = LAST_CHARTED.ITEM_ID
	AND DOSES.ENCNTR_ID = BAGS_YESTERDAY.ENCNTR_ID
	AND DOSES.EVENT_CD = BAGS_YESTERDAY.EVENT_CD
	--AND DOSES.ITEM_ID = BAGS_YESTERDAY.ITEM_ID
	AND DOSES.IV_EVENT_CD IN (
		688706, -- Begin Bag
		688709 -- Rate Change
	)
	AND DOSES.ORDER_ID = ORDERS.ORDER_ID
	AND ORDERS.ORDER_STATUS_CD = 1386 -- Ordered
	AND DOSES.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
	AND DOSES.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
	AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
	AND DOSES.PERSON_ID = PERSON.PERSON_ID
	AND ORDERS.ORDER_ID = ORDER_DETAIL.ORDER_ID(+)
	AND ORDER_DETAIL.OE_FIELD_MEANING_ID(+) = 99 -- WEIGHT
	AND ORDER_DETAIL.ACTION_SEQUENCE(+) = 1
	AND ORDERS.ORDER_ID = OD_WT_UNITS.ORDER_ID(+)
	AND OD_WT_UNITS.OE_FIELD_MEANING_ID(+) = 100 -- WEIGHTUNIT
	AND OD_WT_UNITS.ACTION_SEQUENCE(+) = 1
GROUP BY
	DOSES.EVENT_CD,
	--MED_IDENTIFIER.VALUE,
	ENCOUNTER.LOC_NURSE_UNIT_CD,
	ENCNTR_ALIAS.ALIAS,
	PERSON.NAME_FULL_FORMATTED,
	LAST_CHARTED.LAST_CHARTED_DT_TM,
	ORDERS.ORDER_STATUS_CD,
	ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE,
	OD_WT_UNITS.OE_FIELD_DISPLAY_VALUE,
	MED_DISPENSE.STRENGTH,
	MED_DISPENSE.STRENGTH_UNIT_CD,
	MED_DISPENSE.VOLUME,
	MED_DISPENSE.VOLUME_UNIT_CD,
	BAGS_YESTERDAY.BAGS_LAST_24H
	
-- //clinisilonhh/PHI_Access$/PHI-HER - Pharmacy Adult/Batch IV Current Rates