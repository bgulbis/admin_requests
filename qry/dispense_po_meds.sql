WITH PATIENTS AS (
	SELECT DISTINCT
		ENCOUNTER.ENCNTR_ID,
		ENCOUNTER.PERSON_ID
	FROM
		ENCNTR_LOC_HIST,
		ENCOUNTER
	WHERE
		ENCOUNTER.ORGANIZATION_ID = 1 -- Memorial Hermann Hospital
		AND ENCOUNTER.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= 
			DECODE(
				@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:0),
				'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1, 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter begin date', 'D', , mono, free, persistent, {'05/01/2021 00:00:00'}, User:1),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					),
					pi_time_zone(1, 'America/Chicago')
				)
			)
		AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= 
			DECODE(
				@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:0),
				'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1/86400, 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter end date', 'D', , mono, free, persistent, {'05/01/2022 00:00:00'}, User:2),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					) - 1/86400,
					pi_time_zone(1, 'America/Chicago')
				)
			)
		AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3822, -- HH Trans Care
			3823 -- HH Rehab			
		)		
		AND ENCNTR_LOC_HIST.ACTIVE_IND = 1
), DOSES AS (
	SELECT DISTINCT
		PATIENTS.ENCNTR_ID,
		PATIENTS.PERSON_ID,
		CASE
			WHEN ORDERS.TEMPLATE_ORDER_ID = 0 THEN ORDERS.ORDER_ID
			ELSE ORDERS.TEMPLATE_ORDER_ID
		END AS ORIG_ORDER_ID,
		-- CLINICAL_EVENT.EVENT_END_DT_TM,
		-- pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago') AS MED_DATETIME,
		CLINICAL_EVENT.EVENT_ID,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS MEDICATION,
		-- CE_MED_RESULT.ADMIN_DOSAGE AS DOSE,
		-- pi_get_cv_display(CE_MED_RESULT.DOSAGE_UNIT_CD) AS DOSE_UNIT,
		-- CE_MED_RESULT.INFUSION_RATE AS RATE,
		-- pi_get_cv_display(CE_MED_RESULT.INFUSION_UNIT_CD) AS RATE_UNIT,
		pi_get_cv_display(CE_MED_RESULT.ADMIN_ROUTE_CD) AS ROUTE,
		-- pi_get_cv_display(CE_MED_RESULT.IV_EVENT_CD) AS IV_EVENT,
		pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CLASS_CD) AS EVENT_CLASS
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		ENCNTR_LOC_HIST,
		ORDERS,
		PATIENTS
	WHERE
		-- CLINICAL_EVENT.EVENT_CD = 37557647 -- naloxone
		PATIENTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 158 -- MED
		AND PATIENTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN
			DECODE(
				@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:0),
				'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1, 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter begin date', 'D', , mono, free, persistent, {'05/01/2021 00:00:00'}, User:1),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					),
					pi_time_zone(1, 'America/Chicago')
				)
			)
			AND DECODE(
				@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:0),
				'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1/86400, 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter end date', 'D', , mono, free, persistent, {'05/01/2022 00:00:00'}, User:2),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					) - 1/86400,
					pi_time_zone(1, 'America/Chicago')
				)
			)
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CE_MED_RESULT.ADMIN_DOSAGE > 0 
		AND CE_MED_RESULT.IV_EVENT_CD = 0
/* 		AND CE_MED_RESULT.ADMIN_ROUTE_CD NOT IN (
			508984, -- IV
			9022513, -- INJ
			9022647, -- IVPB
			9022649 -- IVP	
		) */
		AND CE_MED_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
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
		AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3822, -- HH Trans Care
			3823 -- HH Rehab			
		)	
/* 		AND ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD IN (
			4137, -- HH CCU
			5541, -- HH CVICU
			267504362, -- HH CVIMU
			891909143, -- HVI CIMU
			1993318732, -- HH HFIC
			1993319326 -- HH HFIM
		) */
		AND ENCNTR_LOC_HIST.ACTIVE_IND = 1
		AND CLINICAL_EVENT.ORDER_ID = ORDERS.ORDER_ID
), ORD_DETAILS AS (
	SELECT DISTINCT
		ORDER_DETAIL.ORDER_ID,
		ORDER_DETAIL.OE_FIELD_MEANING,
		ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE
	FROM
		DOSES,
		ORDER_DETAIL
	WHERE
		DOSES.ORIG_ORDER_ID = ORDER_DETAIL.ORDER_ID
		AND ORDER_DETAIL.ACTION_SEQUENCE = 1
), ORD_DETAIL_PIVOT AS (
	SELECT * FROM ORD_DETAILS
	PIVOT(
		MIN(OE_FIELD_DISPLAY_VALUE) FOR OE_FIELD_MEANING IN (
			'DRUGFORM' AS DRUG_FORM,
			'DISPENSEFROMLOC' AS DISPENSE_FROM_LOC
		)
	)
)

SELECT DISTINCT
	DOSES.*,
	ORD_DETAIL_PIVOT.DRUG_FORM,
	ORD_DETAIL_PIVOT.DISPENSE_FROM_LOC
FROM
	DOSES,
	ORD_DETAIL_PIVOT
WHERE
	DOSES.ORIG_ORDER_ID = ORD_DETAIL_PIVOT.ORDER_ID
	AND DOSES.EVENT_CLASS = 'MED'
	AND DOSES.ROUTE NOT IN ('IV', 'IVP', 'IVPB', 'INJ', 'IM', 'SUB-Q')
