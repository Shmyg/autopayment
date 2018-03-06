/*
|| Autopayment objects creation
|| Created by Shmyg
|| LMD by Shmyg 19.12.2003
*/

ACCEPT owner  DEFAULT aval PROMPT "Enter user name [aval]: "
ACCEPT deftsp PROMPT "Enter Default tablespace name: "
ACCEPT tmptsp PROMPT "Enter Temp tablespace name: "
ACCEPT indtsp PROMPT "Enter Index tablespace name: "

SET ECHO ON
SET FEEDBACK  ON
SET HEADING  ON
SET VERIFY  ON

SPOOL /tmp/ReConnect.sql

SELECT	'connect '||user||'@'||name||';'
FROM	v$database;

SPOOL OFF

SPOOL /tmp/ConnDonor.sql

SELECT	'connect DONOR@'||name||';'
FROM	v$database;

SPOOL OFF

SPOOL /tmp/ConnSysadm.sql

SELECT	'connect SYSADM@'||name||';'
FROM	v$database;

SPOOL OFF

spool /tmp/&owner..log

-- Added 26.11.2003
CREATE	TABLE &owner..file_statuses
	(
	file_status	VARCHAR2(2) NOT NULL,
	description	VARCHAR2(40) NOT NULL,
	CONSTRAINT	pkfile_statuses
	PRIMARY	KEY ( file_status )
	)
PCTFREE    5
PCTUSED    40
INITRANS   1
MAXTRANS   255
/

COMMENT	ON TABLE &owner..file_statuses IS 'Autopayment file statuses'
/

INSERT	INTO &owner..file_statuses
VALUES	(
	'00',
	'Just loaded'
	)
/

INSERT	INTO &owner..file_statuses
VALUES	(
	'01',
	'Checked'
	)
/

INSERT	INTO &owner..file_statuses
VALUES	(
	'02',
	'Processed'
	)
/

INSERT	INTO &owner..file_statuses
VALUES	(
	'03',
	'Processed with warnings'
	)
/

INSERT	INTO &owner..file_statuses
VALUES	(
	'10',
	'Duplicate file'
	)
/

CREATE	TABLE &owner..umc_payment_files
	(
	file_id		NUMBER NOT NULL,
	file_name	VARCHAR(15) NOT NULL,
	entdate		DATE NOT NULL,
	gl_code		VARCHAR2(30) NOT NULL,
	file_status	VARCHAR2(2) DEFAULT '00' NOT NULL,
	CONSTRAINT	pk_umc_pay_files
	PRIMARY	KEY ( file_id ),
	CONSTRAINT	fk_file_status
	FOREIGN	KEY ( file_status )
	REFERENCES	&owner..file_statuses
	)
PCTFREE    5
PCTUSED    40
INITRANS   1
MAXTRANS   255
/

COMMENT ON TABLE &owner..umc_payment_files
IS	'Autopayment files'
/

COMMENT ON COLUMN &owner..umc_payment_files.file_id
IS	'File ID - PK'
/

COMMENT ON COLUMN &owner..umc_payment_files.file_status
IS	'Current status - FK to FILE_STATUSES'
/

CREATE	TABLE &owner..umc_customer_payments
	(
	file_id		NUMBER NOT NULL,
	line_num	NUMBER NOT NULL,
	amount		NUMBER NOT NULL,
	phone_number	VARCHAR2(7),
	custcode	VARCHAR2(24),
	customer_id	NUMBER,
	processed	VARCHAR2(1),
	err_message	VARCHAR2(200),
	CONSTRAINT	pk_umc_cust_pay
	PRIMARY	KEY ( file_id, line_num )
	)
PCTFREE    10
PCTUSED    40
INITRANS   1
MAXTRANS   255
/

COMMENT ON COLUMN &owner..umc_customer_payments.processed
IS	'Flag. Valid values:
	NULL - customer is not processed,
	X - customer processed successfully,
	E - customer processed with errors'
/


ALTER	TABLE &owner..umc_customer_payments
ADD	CONSTRAINT fk_file_id
FOREIGN	KEY ( file_id )
REFERENCES	&owner..umc_payment_files ( file_id )
/

@/tmp/ConnSysadm

GRANT SELECT ON contract_all TO &owner.
/

GRANT SELECT ON contr_services_cap TO &owner.
/

GRANT SELECT ON directory_number TO &owner.
/

@/tmp/ReConnect

@aval_util.pks
@aval_util.pkb
@bef_ins_umc_cust_pay_trg.sql
@bef_ins_umc_pay_files_trg.sql

@/tmp/ConnDonor.sql

GRANT	EXECUTE ON donor.payment_t TO &owner.
/
GRANT	EXECUTE ON donor.cashdetail_tab TO &owner.
/
GRANT	EXECUTE ON donor.order_t TO &owner.
/
GRANT	EXECUTE ON donor.order_tab TO &owner.
/

!rm /tmp/&owner..log

SET ECHO OFF
SET FEEDBACK  OFF
SET HEADING  OFF
SET VERIFY  OFF
