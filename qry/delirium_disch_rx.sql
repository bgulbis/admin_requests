SELECT DISTINCT
	ORDERS.ENCNTR_ID,
	ENCNTR_ALIAS.ALIAS AS FIN,
	pi_get_cv_display(ORDERS.CATALOG_CD) AS MEDICATION,
	pi_get_cv_display(ENCOUNTER.LOC_NURSE_UNIT_CD) AS DISCH_NURSE_UNIT
FROM
	ENCNTR_ALIAS,
	ENCOUNTER,
	ORDERS
WHERE
	ORDERS.CATALOG_CD IN (
		9902748, -- haloperidol
		9912119, -- OLANZapine
		9912616, -- QUEtiapine
		11732705 -- ziprasidone
	)
	AND ORDERS.ORIG_ORDER_DT_TM BETWEEN
		pi_to_gmt(
			TO_DATE(
				@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2019 00:00:00'}, User:0), 
				pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
			), 
			'America/Chicago'
		)
		AND pi_to_gmt(
			TO_DATE(
				@Prompt('Enter end date', 'D', , mono, free, persistent, {'7/01/2020 00:00:00'}, User:1), 
				pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
			) - 1/86400, 
			'America/Chicago'
		)
	AND ORDERS.ORIG_ORD_AS_FLAG = 1 -- Prescription/Discharge Order
	AND ORDERS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
	AND ENCOUNTER.LOC_NURSE_UNIT_CD IN (
		4356, -- HH 6EJP
		1542800, -- HH 6WJP
		16163788, -- HH 8NJP
		8667295, -- HH 3JP
		2428498395, -- HH S1MU
		3224987147, -- HH S SITU
		3224987399, -- HH S SIMU
		3224988029, -- HH S OTAC
		1846341943, -- HH 3CP
		1846342787, -- HH 3CIM
		3955, -- HH 4WCP
		265179687 -- HH ACE
	)
	AND ORDERS.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
	AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
	AND ENCNTR_ALIAS.ACTIVE_IND = 1

--Restraints Non-Violent Reassess Or Reorder