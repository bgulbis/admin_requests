WITH DOSES AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID,
		CASE
			WHEN ORDERS.TEMPLATE_ORDER_ID = 0 THEN ORDERS.ORDER_ID
			ELSE ORDERS.TEMPLATE_ORDER_ID
		END AS ORIG_ORDER_ID,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago') AS MED_DATETIME,
		CLINICAL_EVENT.EVENT_ID,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS MEDICATION,
		pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS NURSE_UNIT
	FROM 
		CLINICAL_EVENT,
		ENCNTR_LOC_HIST,
		ORDERS
	WHERE
		CLINICAL_EVENT.EVENT_CD IN (
			333892112, -- CRRT Output Vol
			173565025 -- CRRT Actual Pt Fluid Removed Vol
		)
		-- AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN pi_to_gmt(SYSDATE - 1, 'America/Chicago') AND pi_to_gmt(SYSDATE, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= CLINICAL_EVENT.EVENT_END_DT_TM
		AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
			SELECT MAX(ELH.TRANSACTION_DT_TM)
			FROM ENCNTR_LOC_HIST ELH
			WHERE
				CLINICAL_EVENT.ENCNTR_ID = ELH.ENCNTR_ID
				AND ELH.TRANSACTION_DT_TM <= CLINICAL_EVENT.EVENT_END_DT_TM
				AND ELH.ACTIVE_IND = 1
		)
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= CLINICAL_EVENT.EVENT_END_DT_TM
		AND ENCNTR_LOC_HIST.ACTIVE_IND = 1   
		AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823 -- HH Rehab		
		)
		AND CLINICAL_EVENT.ORDER_ID = ORDERS.ORDER_ID
)

SELECT DISTINCT
	ENCNTR_ALIAS.ALIAS AS FIN,
	DOSES.*
	-- MED_IDENTIFIER.VALUE AS PRODUCT
FROM
	DOSES,
	ENCNTR_ALIAS
	-- MED_IDENTIFIER,
	-- ORDER_PRODUCT
WHERE
	-- DOSES.ORIG_ORDER_ID = ORDER_PRODUCT.ORDER_ID
	-- AND ORDER_PRODUCT.ACTION_SEQUENCE = 1
	-- -- AND ORDER_PRODUCT.INGRED_SEQUENCE = 1
	-- AND ORDER_PRODUCT.ITEM_ID = MED_IDENTIFIER.ITEM_ID
	-- AND MED_IDENTIFIER.MED_IDENTIFIER_TYPE_CD = 1564 -- Generic Name
	-- AND MED_IDENTIFIER.MED_PRODUCT_ID = 0
/* 	AND MED_IDENTIFIER.ITEM_ID IN (
		2892797, -- DOBUTamine 1000mg/250 ml D5W premix
		2896042, -- DOBUTamine 250 mg/20ml INJ VL
		153497896 -- DOBUTamine 4 mg/mL INJ (ANES)
	) */
	DOSES.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
	AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
	AND ENCNTR_ALIAS.ACTIVE_IND = 1