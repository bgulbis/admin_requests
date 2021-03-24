WITH ABX_ORDERS AS (
	SELECT DISTINCT
		ORDERS.ENCNTR_ID,
		ORDERS.ORDER_ID,
		ORDERS.ORIG_ORDER_DT_TM,
		ORDERS.CURRENT_START_DT_TM,
		ENCNTR_LOC_HIST.LOC_FACILITY_CD,
		ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD,
		'ABX' AS ORDER_GROUP
	FROM
		ENCNTR_LOC_HIST,
		FREQUENCY_SCHEDULE,
		ORDER_DETAIL,
		ORDERS
	WHERE
		ORDERS.CATALOG_CD IN (
			9902621, -- ampicillin
			9902636, -- ceFAZolin
			9902640, -- cefotaxime
			9902644, -- cefTAZidime
			9902652, -- ceftizoxime
			9902655, -- ciprofloxacin
			9902666, -- gentamicin
			9902742, -- chloramphenicol
			9902760, -- nafcillin
			9902764, -- pentamidine
			9902789, -- doxycycline
			9902815, -- tetracycline
			9902824, -- clindamycin
			9902846, -- erythromycin
			9902863, -- rifaMPIN
			9902910, -- cefTRIAXone
			9902914, -- cephradine
			9902923, -- cefoTEtan
			9902928, -- cefuroxime
			9902933, -- piperacillin
			9902991, -- aztreonam
			9902998, -- tobramycin
			9903014, -- cefixime
			9903017, -- cefprozil
			9903020, -- cefoperazone
			9903045, -- cefadroxil
			9903048, -- cefaclor
			9903053, -- imipenem-cilastatin
			9903087, -- amikacin
			9903091, -- amoxicillin
			9903097, -- amoxicillin-clavulanate
			9903100, -- ampicillin-sulbactam
			9903103, -- azithromycin
			9903108, -- carbenicillin
			9903111, -- cefOXitin
			9903114, -- cefpodoxime
			9903118, -- cephalexin
			9903124, -- clarithromycin
			9903128, -- dapsone
			9903130, -- enoxacin
			9903153, -- lomefloxacin
			9903156, -- loracarbef
			9903161, -- methenamine
			9903167, -- methicillin
			9903170, -- metroNIDAZOLE
			9903188, -- minocycline
			9903196, -- nitrofurantoin
			9903201, -- norfloxacin
			9903204, -- ofloxacin
			9903209, -- oxacillin
			9903243, -- trimethoprim
			9903248, -- sulfamethoxazole-trimethoprim
			9903263, -- vancomycin
			9903393, -- cloxacillin
			9903396, -- dicloxacillin
			9903404, -- nalidixic acid
			9903409, -- streptomycin
			9903536, -- cephapirin
			9903845, -- furazolidone
			9903938, -- kanamycin
			9904101, -- neomycin
			9904382, -- spectinomycin
			9906304, -- demeclocycline
			9906310, -- troleandomycin
			9906313, -- rifabutin
			9906326, -- paromomycin
			9906335, -- colistimethate
			9906343, -- atovaquone
			9906347, -- clofazimine
			9906364, -- cinoxacin
			9908150, -- piperacillin-tazobactam
			9908158, -- trimetrexate
			9910230, -- erythromycin-sulfisoxazole
			9911521, -- dirithromycin
			9911598, -- ceftibuten
			9911615, -- cefepime
			9912037, -- meropenem
			9912285, -- fosfomycin
			9912301, -- levofloxacin
			9912705, -- lidocaine-oxytetracycline
			9912743, -- cefdinir
			9912765, -- alatrofloxacin
			9912967, -- thalidomide
			9913495, -- moxifloxacin
			9913505, -- gatifloxacin
			9913587, -- linezolid
			33986780, -- DAPTOmycin
			52483156, -- riFAXimin
			86475884, -- tigecycline
			99263364, -- gemifloxacin
			118550016, -- cefditoren
			118552591, -- clavulanate
			118569035, -- lincomycin
			118570747, -- methenamine-sodium acid phosphate
			118570751, -- methenamine-sodium biphosphate
			118580644, -- rifapentine
			118583365, -- sparfloxacin
			118583520, -- sulbactam
			118583762, -- sulfadoxine
			118583794, -- sulfamethoxazole
			118584081, -- tazobactam
			118893837, -- bacitracin
			118898797, -- ertapenem
			118901857, -- polymyxin B sulfate
			118902639, -- sulfADIAZINE
			118902738, -- sulfiSOXAZOLE
			120633092, -- imipenem
			255617082, -- doripenem
			352420682, -- doxycycline-omega 3 fatty acids
			352421745, -- procaine penicillin
			386593991, -- doxycycline-salicylic acid topical
			443758826, -- telavancin
			583223985, -- ceftaroline
			609787482, -- penicillin G potassium
			609787843, -- penicillin G benzathine
			609787876, -- penicillin V potassium
			609788263, -- penicillin G sodium
			635210916, -- fidaxomicin
			1233615382, -- tedizolid
			1233615411, -- dalbavancin
			1319239785, -- oritavancin
			1369223557, -- ceftolozane-tazobactam
			1417998482, -- ceftolozane
			1499629784, -- ceftazidime-avibactam
			1651062909, -- avibactam
			2737463267, -- delafloxacin
			2737463829, -- meropenem-vaborbactam
			2841973963, -- dexamethasone/ketorolac/moxifloxacin
			2841974161, -- plazomicin
			2841974285, -- secnidazole
			2841975169, -- moxifloxacin-triamcinolone
			2841975639, -- dexamethasone-moxifloxacin
			2923069051, -- benznidazole
			2923069853, -- amikacin liposome
			2923070379, -- eravacycline
			3135804669, -- rifamycin
			3135805929, -- omadacycline
			3135806071 -- sarecycline
		)
		AND ORDERS.TEMPLATE_ORDER_ID = 0
		AND ORDERS.CURRENT_START_DT_TM BETWEEN
			pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2019 00:00:00'}, User:80),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				),
				'America/Chicago'
			)
			AND pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'07/01/2020 00:00:00'}, User:81),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400,
				'America/Chicago'
			)
		AND ORDERS.ORIG_ORD_AS_FLAG = 0
		AND ORDERS.PRN_IND = 0
		AND (ORDERS.CURRENT_START_DT_TM - ORDERS.ORIG_ORDER_DT_TM) <= (1 / 24)
		AND ORDERS.FREQUENCY_ID = FREQUENCY_SCHEDULE.FREQUENCY_ID
		AND FREQUENCY_SCHEDULE.FREQUENCY_CD NOT IN (
			9054354, -- ONCALL
			9923409 -- PRE OP
		)		
		AND ORDERS.ORDER_ID = ORDER_DETAIL.ORDER_ID
		AND ORDER_DETAIL.OE_FIELD_MEANING_ID = 2050 -- RXROUTE
		AND ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE IN ('IM', 'IV', 'IVP', 'IVPB')
		AND ORDER_DETAIL.ACTION_SEQUENCE = 1
		AND ORDERS.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
		AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
			SELECT MAX(ELH.TRANSACTION_DT_TM)
			FROM ENCNTR_LOC_HIST ELH
			WHERE
				ORDERS.ENCNTR_ID = ELH.ENCNTR_ID
				AND ELH.TRANSACTION_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
		)
		AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823 -- HH Rehab
		)
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= ORDERS.ORIG_ORDER_DT_TM
		AND ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD NOT IN (
			43683126, -- HH AMSA
			43683728 -- HH DSU
		)
), PHARM_ORDERS AS (
	SELECT DISTINCT
		ORDERS.ENCNTR_ID,
		ORDERS.ORDER_ID,
		ORDERS.ORIG_ORDER_DT_TM,
		ORDERS.CURRENT_START_DT_TM,
		ENCNTR_LOC_HIST.LOC_FACILITY_CD,
		ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD,
		ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE AS PRIORITY,
		'STAT' AS ORDER_GROUP
	FROM
		ENCNTR_LOC_HIST,
		ORDER_DETAIL,
		ORDERS
	WHERE
		ORDERS.TEMPLATE_ORDER_ID = 0
		AND ORDERS.CURRENT_START_DT_TM BETWEEN
			pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2019 00:00:00'}, User:80),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				),
				'America/Chicago'
			)
			AND pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'08/01/2019 00:00:00'}, User:81),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400,
				'America/Chicago'
			)
		AND ORDERS.ACTIVITY_TYPE_CD = 378 -- Pharmacy
		AND ORDERS.CATALOG_TYPE_CD = 1363 -- Pharmacy
		AND ORDERS.ORDER_ID = ORDER_DETAIL.ORDER_ID
		AND ORDER_DETAIL.ACTION_SEQUENCE = 1
		AND ORDER_DETAIL.OE_FIELD_MEANING_ID IN (
			127, -- PRIORITY
			141 -- RXPRIORITY
		)
		AND ORDERS.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
		AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
			SELECT MAX(ELH.TRANSACTION_DT_TM)
			FROM ENCNTR_LOC_HIST ELH
			WHERE
				ORDERS.ENCNTR_ID = ELH.ENCNTR_ID
				AND ELH.TRANSACTION_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
		)
		AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823 -- HH Rehab
		)
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= ORDERS.ORIG_ORDER_DT_TM
), STAT_ORDERS AS (
	SELECT
		ENCNTR_ID,
		ORDER_ID,
		ORIG_ORDER_DT_TM,
		CURRENT_START_DT_TM,
		LOC_FACILITY_CD,
		LOC_NURSE_UNIT_CD,
		ORDER_GROUP
	FROM
		PHARM_ORDERS
	WHERE
		PRIORITY IN (
			'STAT',
			'NOW'
		)
), ALL_ORDERS AS (
	SELECT * 
	FROM ABX_ORDERS
	WHERE ABX_ORDERS.ORDER_ID NOT IN (SELECT ORDER_ID FROM STAT_ORDERS)
	
	UNION
	
	SELECT * FROM STAT_ORDERS
), ORDER_VERIFY AS (
	SELECT DISTINCT
		ALL_ORDERS.ORDER_ID,
		MIN(ORDER_REVIEW.REVIEW_DT_TM) AS REVIEW_DT_TM
	FROM
		ALL_ORDERS,
		ORDER_REVIEW
	WHERE
		ALL_ORDERS.ORDER_ID = ORDER_REVIEW.ORDER_ID
		AND ORDER_REVIEW.ACTION_SEQUENCE = 1
		AND ORDER_REVIEW.REVIEW_TYPE_FLAG = 3
		AND ORDER_REVIEW.REVIEWED_STATUS_FLAG = 1 -- IN (1, 5)
		AND ORDER_REVIEW.REVIEW_PERSONNEL_ID > 1
	GROUP BY 
		ALL_ORDERS.ORDER_ID
), CHILD_ORDERS AS (
	SELECT DISTINCT
		ALL_ORDERS.*,
		ORDER_VERIFY.REVIEW_DT_TM,
		COALESCE(ORDERS.ORDER_ID, ORDER_VERIFY.ORDER_ID) AS EVENT_ORDER_ID
	FROM
		ALL_ORDERS,
		ORDER_VERIFY,
		ORDERS
	WHERE
		ALL_ORDERS.ORDER_ID = ORDER_VERIFY.ORDER_ID
		AND ALL_ORDERS.ORDER_ID = ORDERS.TEMPLATE_ORDER_ID(+)
), DOSES AS (
	SELECT DISTINCT
		CHILD_ORDERS.ENCNTR_ID,
		CHILD_ORDERS.ORDER_ID,
		MIN(CLINICAL_EVENT.EVENT_END_DT_TM) AS EVENT_END_DT_TM
	FROM
		CE_MED_RESULT,
		CHILD_ORDERS,
		CLINICAL_EVENT
	WHERE
		CHILD_ORDERS.EVENT_ORDER_ID = CLINICAL_EVENT.ORDER_ID
		AND CLINICAL_EVENT.VALID_FROM_DT_TM >= CHILD_ORDERS.ORIG_ORDER_DT_TM
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CE_MED_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND (CE_MED_RESULT.ADMIN_DOSAGE > 0 OR CE_MED_RESULT.INFUSION_RATE > 0)
	GROUP BY
		CHILD_ORDERS.ENCNTR_ID,
		CHILD_ORDERS.ORDER_ID		
)

SELECT
	pi_from_gmt(ALL_ORDERS.ORIG_ORDER_DT_TM, 'America/Chicago') AS ORDER_DATETIME,
	ALL_ORDERS.ORDER_ID,
	ALL_ORDERS.ENCNTR_ID,
	TRUNC(pi_from_gmt(ALL_ORDERS.ORIG_ORDER_DT_TM, 'America/Chicago')) AS ORDER_DATE,
	TRUNC(pi_from_gmt(ALL_ORDERS.ORIG_ORDER_DT_TM, 'America/Chicago'), 'MONTH') AS ORDER_MONTH,
	pi_from_gmt(ALL_ORDERS.CURRENT_START_DT_TM, 'America/Chicago') AS START_DATETIME,
	pi_from_gmt(ORDER_VERIFY.REVIEW_DT_TM, 'America/Chicago') AS REVIEW_DATETIME,
	pi_from_gmt(DOSES.EVENT_END_DT_TM, 'America/Chicago') AS DOSE_DATETIME,
	(ORDER_VERIFY.REVIEW_DT_TM - ALL_ORDERS.ORIG_ORDER_DT_TM) * 24 * 60 AS ORDER_VERIFY_MIN,
	(DOSES.EVENT_END_DT_TM - ORDER_VERIFY.REVIEW_DT_TM) * 24 * 60 AS VERIFY_ADMIN_MIN,
	(DOSES.EVENT_END_DT_TM - ALL_ORDERS.ORIG_ORDER_DT_TM) * 24 * 60 AS ORDER_ADMIN_MIN,
	pi_get_cv_display(ALL_ORDERS.LOC_FACILITY_CD) AS FACILITY,
	pi_get_cv_display(ALL_ORDERS.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
	ALL_ORDERS.ORDER_GROUP
FROM
	ALL_ORDERS,
	DOSES,
	ORDER_VERIFY
WHERE
	ALL_ORDERS.ORDER_ID = ORDER_VERIFY.ORDER_ID
	AND ALL_ORDERS.ORDER_ID = DOSES.ORDER_ID
	AND DOSES.EVENT_END_DT_TM > ALL_ORDERS.ORIG_ORDER_DT_TM
	AND DOSES.EVENT_END_DT_TM > ORDER_VERIFY.REVIEW_DT_TM
	AND ALL_ORDERS.ORIG_ORDER_DT_TM BETWEEN
		pi_to_gmt(
			TO_DATE(
				@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2019 00:00:00'}, User:80),
				pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
			),
			'America/Chicago'
		)
		AND pi_to_gmt(
			TO_DATE(
				@Prompt('Enter end date', 'D', , mono, free, persistent, {'07/01/2020 00:00:00'}, User:81),
				pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
			) - 1/86400,
			'America/Chicago'
		)
