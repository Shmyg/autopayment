CREATE	OR REPLACE
PACKAGE	BODY &owner..aval_util
AS

PROCEDURE	fill_customer_payments
IS
	-- Cursor for all the customers who hasn't customer_id yet
	CURSOR	customer_cur
	IS
	SELECT	customer_id,
		custcode,
		'50' || phone_number
	FROM	aval.umc_customer_payments
	WHERE	customer_id IS NULL
	AND	processed IS NULL
	FOR	UPDATE OF customer_id;

	-- Cursor for searching customer_id by custcode
	CURSOR	custcode_cur
		(
		p_custcode	VARCHAR
		)
	IS
	SELECT	customer_id
	FROM	customer_all
	WHERE	custcode = p_custcode;

	-- Cursor for searching customer_id by dn_num
	CURSOR	dn_num_cur
		(
		p_dn_num	VARCHAR
		)
	IS
	SELECT	ca.customer_id
	FROM	contract_all		ca,
		contr_services_cap	cs,
		directory_number	dn
	WHERE	dn.dn_id = cs.dn_id
	AND	cs.co_id = ca.co_id
	AND	dn.dn_num = p_dn_num
	AND	cs.cs_deactiv_date IS NULL;

	v_customer_id		customer_all.customer_id%TYPE;
	v_custcode		customer_all.custcode%TYPE;
	v_dn_num		VARCHAR2(9);

BEGIN

	OPEN	customer_cur;
	LOOP
		FETCH	customer_cur
		INTO	v_customer_id,
			v_custcode,
			v_dn_num;
		EXIT	WHEN customer_cur%NOTFOUND;

		IF	v_custcode IS NOT NULL
		THEN
			-- Trying to find customer_id by custcode
			OPEN	custcode_cur( v_custcode );

				FETCH	custcode_cur
				INTO	v_customer_id;

			CLOSE	custcode_cur;

			IF	v_customer_id IS NULL -- We didn't find customer_id
			THEN
				-- Maybe we can use dn_num
				IF	v_dn_num IS NOT NULL
				THEN
					-- Trying to find id by phone					
					OPEN	dn_num_cur( v_dn_num );

						FETCH	dn_num_cur
						INTO	v_customer_id;

					CLOSE	dn_num_cur;
				END	IF;
			END	IF;

		-- Custcode is not null - trying dn_num
		ELSIF	v_dn_num IS NOT NULL
		THEN
			OPEN	dn_num_cur( v_dn_num );

				FETCH	dn_num_cur
				INTO	v_customer_id;

			CLOSE	dn_num_cur;
		END	IF;
		
		UPDATE	aval.umc_customer_payments
		SET	customer_id = v_customer_id
		WHERE	CURRENT OF customer_cur;

	END	LOOP;

END	fill_customer_payments;

END	aval_util;
/

SHOW ERROR
