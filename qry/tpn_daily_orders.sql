SELECT DISTINCT
	pi_get_cv_display(ORDERS.CATALOG_CD) AS TPN_ORDER,
	PERSON.NAME_FULL_FORMATTED AS PATIENT_NAME,
	ENCNTR_ALIAS.ALIAS AS FIN,
	pi_from_gmt(ORDERS.ORIG_ORDER_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS ORDER_DATETIME,
	pi_get_cv_display(ENCOUNTER.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
	PRSNL.NAME_FULL_FORMATTED AS PROVIDER
FROM
	ENCNTR_ALIAS,
	ENCOUNTER,
	ORDER_ACTION,
	ORDERS,
	PERSON,
	PRSNL
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
		pi_to_gmt(TRUNC(SYSDATE), pi_time_zone(2, @Variable('BOUSER')))
		AND pi_to_gmt(SYSDATE, pi_time_zone(2, @Variable('BOUSER')))
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
	AND ENCOUNTER.PERSON_ID = PERSON.PERSON_ID
	AND ORDERS.ORDER_ID = ORDER_ACTION.ORDER_ID
	AND ORDER_ACTION.ACTION_TYPE_CD = 1376 -- Order
	AND ORDER_ACTION.ORDER_PROVIDER_ID = PRSNL.PERSON_ID
	
-- //clinisilonhh/PHI_Access$/PHI-HER - Pharmacy Adult/TPN Daily Orders