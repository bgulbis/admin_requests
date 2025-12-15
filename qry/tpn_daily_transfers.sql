SELECT DISTINCT
	PERSON.NAME_FULL_FORMATTED AS PATIENT_NAME,
	ENCNTR_ALIAS.ALIAS AS FIN,
	-- pi_from_gmt(ORDERS.ORIG_ORDER_DT_TM, 'America/Chicago') AS ORDER_DATETIME,
	pi_get_cv_display(ENCOUNTER.LOC_NURSE_UNIT_CD) AS CURR_NURSE_UNIT,
	pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS PREV_NURSE_UNIT
FROM
	ENCNTR_ALIAS,
	ENCNTR_LOC_HIST,
	ENCOUNTER,
	ORDERS,
	PERSON
WHERE
	ORDERS.CATALOG_CD IN (
		2795416141, -- Adult Parenteral Nutrition Order Details - Custom (TPN/PPN)
		2795420321, -- Adult Parenteral Nutrition Order Details - Standard (TPN/PPN
		2837905211, -- Adult Parenteral Nutrition Custom - Central
		2837907025, -- Adult Parenteral Nutrition Custom - Peripheral
		2837909213, -- Adult Parenteral Nutrition Standard - Central
		2837911127, -- Adult Parenteral Nutrition Standard - Peripheral
		793987334, -- TPN Order Details - Pediatric
		775742381, -- TPN Central Order Details - Neonatal
		775746671 -- TPN Peripheral Order Details - Neonatal
	)
	AND	ORDERS.TEMPLATE_ORDER_FLAG IN (0, 1)
	AND ORDERS.ORIG_ORDER_DT_TM BETWEEN
		DECODE(
			@Prompt('Choose date range', 'A', {'Today', 'User-defined'}, mono, free, , , User:79),
			'Today', pi_to_gmt(TRUNC(SYSDATE), 'America/Chicago'),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'01/01/2022 00:00:00'}, User:80),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				),
				'America/Chicago'
			)
		)
		AND DECODE(
			@Prompt('Choose date range', 'A', {'Today', 'User-defined'}, mono, free, , , User:79),
			'Today', pi_to_gmt(SYSDATE, 'America/Chicago'),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'01/02/2022 00:00:00'}, User:81),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400,
				'America/Chicago'
			)
		)
	AND ORDERS.ORIG_ORD_AS_FLAG = 0
	AND ORDERS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
	AND ENCOUNTER.LOC_FACILITY_CD IN (
		3310, -- HH HERMANN
		3796, -- HC Childrens
		3821, -- HH Clinics
		3822, -- HH Trans Care
		3823 -- HH Rehab		
	)
	AND ENCOUNTER.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
	AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR	
	AND ENCNTR_ALIAS.ACTIVE_IND = 1
	AND ENCOUNTER.PERSON_ID = PERSON.PERSON_ID
	AND ORDERS.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
	AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
	AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
		SELECT MAX(ELH.TRANSACTION_DT_TM)
		FROM ENCNTR_LOC_HIST ELH
		WHERE
			ORDERS.ENCNTR_ID = ELH.ENCNTR_ID
			AND ELH.TRANSACTION_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
			AND ELH.ACTIVE_IND = 1
	)
	AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= ORDERS.ORIG_ORDER_DT_TM
	AND ENCNTR_LOC_HIST.ACTIVE_IND = 1
	AND ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD <> ENCOUNTER.LOC_NURSE_UNIT_CD
	
-- //clinisilonhh/PHI_Access$/PHI-HER - Pharmacy Adult/TPN Daily Orders