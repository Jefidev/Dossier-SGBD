CREATE DATABASE LINK CBB.DBL CONNECT TO CBB IDENTIFIED BY CBB USING 'CBB';


CREATE OR REPLACE TRIGGER COPIECOTESAVIS
BEFORE INSERT OR UPDATE ON EVALUATION
FOR EACH ROW
BEGIN

	:NEW.TOKEN := 'OK';

	IF (INSERTING) THEN
		INSERT INTO EVALUATION@CBB.DBL (IDFILM, LOGIN, COTE, AVIS, DATEEVAL, TOKEN)
		VALUES (:NEW.IDFILM, :NEW.LOGIN, :NEW.COTE, :NEW.AVIS, :NEW.DATEEVAL, :NEW.TOKEN);
	END IF;

	IF (UPDATING) THEN
		UPDATE EVALUATION@CBB.DBL
		SET	COTE = :NEW.COTE,
			AVIS = :NEW.AVIS,
			DATEEVAL = :NEW.DATEEVAL,
			TOKEN = :NEW.TOKEN
		WHERE	IDFILM = :NEW.IDFILM AND LOGIN = :NEW.LOGIN;
	END IF;

EXCEPTION
	WHEN OTHERS THEN
		IF SQLCODE = -02291 THEN :NEW.TOKEN = 'KO';
		ELSE RAISE;
		END IF;
END;
/


INSERT INTO EVALUATION VALUES (10, 'LOL', 7, 'Coucou',  to_timestamp('23/09/15 17:24:00','DD/MM/RR HH24:MI:SSXFF'), NULL);