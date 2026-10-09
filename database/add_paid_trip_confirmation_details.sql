START TRANSACTION;


DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261009012220_AddPaidTripConfirmationDetails') THEN
    ALTER TABLE "TransportOptions" ADD "ContactEmail" character varying(254);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261009012220_AddPaidTripConfirmationDetails') THEN
    ALTER TABLE "TransportOptions" ADD "ContactPhone" character varying(30);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261009012220_AddPaidTripConfirmationDetails') THEN
    ALTER TABLE "Notifications" ADD "TripDetailsJson" text;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261009012220_AddPaidTripConfirmationDetails') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20261009012220_AddPaidTripConfirmationDetails', '8.0.10');
    END IF;
END $EF$;
COMMIT;
