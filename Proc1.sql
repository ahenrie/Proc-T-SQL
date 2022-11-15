--1. Proc to fill dwTerminalsAgg with full replacement pause constraints and suspend REF integ
ALTER PROC fillTerminalsAgg
AS
BEGIN
    ALTER TABLE dwShipmentFacts
    NOCHECK CONSTRAINT FK__dwShipmen__Origi__787EE5A0
    ALTER TABLE dwShipmentFacts
    NOCHECK CONSTRAINT FK__dwShipmen__Desti__797309D9
    DELETE FROM dwTerminalsAgg
    INSERT INTO dwTerminalsAgg
		SELECT DISTINCT d.DepartCode, COUNT(d.ShipmentID), arriveCount,GETDATE()
		FROM Shipments d JOIN
			(SELECT DISTINCT ArriveCode, COUNT(ShipmentID) AS arriveCount
			 FROM Shipments 
			 GROUP BY ArriveCode) a
		ON a.ArriveCode = d.DepartCode
		GROUP BY d.DepartCode, a.ArriveCode, a.arriveCount;
    ALTER TABLE dwShipmentFacts
    CHECK CONSTRAINT FK__dwShipmen__Origi__787EE5A0
    ALTER TABLE dwShipmentFacts
    CHECK CONSTRAINT FK__dwShipmen__Desti__797309D9
END;
GO
EXEC fillTerminalsAgg;
SELECT * FROM dwTerminalsAgg;



--2. Proc Write a stored procedure that will populate the dwTrucksDim data warehouse table with a full replacement update each time the procedure is run.
ALTER PROC fillTrucksDim
	(@DaysSince INT, @WhenToService INT)
AS
BEGIN
	ALTER TABLE dwShipmentFacts
	NOCHECK CONSTRAINT FK__dwShipmentF__VIN__75A278F5;
	DELETE FROM dwTrucksDim;
	INSERT INTO dwTrucksDim
	SELECT VIN, Manufacturer, Model, DatePurchased, HaulingCap, LastServiceDate, 
		CASE
			WHEN DATEDIFF(d,LastServiceDate,GETDATE()) > @DaysSince AND DATEDIFF(d,LastServiceDate,GETDATE()) > @WhenToService THEN 'Out Of Service'
			WHEN DATEDIFF(d,LastServiceDate,GETDATE()) < @DaysSince THEN 'Current'
			ELSE 'Service Soon'
		END, 
			GETDATE()
FROM Trucks;
	ALTER TABLE dwShipmentFacts
	CHECK CONSTRAINT FK__dwShipmentF__VIN__75A278F5;
END;
GO
EXEC fillTrucksDim @DaysSince = 100, @WhenToService = 300;


--3. Proc to populate dwCarriers with incremental updates
ALTER PROC fillCarriersDim
AS
BEGIN
	INSERT INTO dwCarriersDim
		SELECT CarrierID, CarrierName, GETDATE()
		FROM Carriers
		WHERE CarrierID NOT IN (SELECT CarrierID FROM dwCarriersDim)
END;
GO
EXEC fillCarriersDim;


--4. Proc to populate dwDateDim with no updates. Populate every hour in everyday 2022-2023
ALTER PROC fillDateDim
	(@StartDate DATETIME, @EndDate DATETIME)
AS
BEGIN
	WHILE @StartDate < @EndDate
	BEGIN
		INSERT INTO dwDateDim
		VALUES(@StartDate, DATEPART(HOUR,@StartDate),DATENAME(WEEKDAY, @StartDate), 
		DATENAME(MONTH, @StartDate), DATEPART(QUARTER, @StartDate), YEAR(@StartDate), GETDATE());
		SET @StartDate = DATEADD(HOUR, 1, @StartDate);
	END;
END;
GO
EXEC fillDateDim @StartDate = '1/1/2022', @EndDate = '1/1/2024';

SELECT * FROM dwDateDim;
DELETE FROM dwDateDim;

--5. Write a stored procedure that will populate the dwShipmentFacts data warehouse table with no update
ALTER PROC fillShipmentFacts
AS
BEGIN
    INSERT INTO dwShipmentFacts
    SELECT ShipmentID, VIN, CarrierID, DepartCode, ArriveCode, 
	NULL, NULL, DepartDateTime, ArriveDateTime, GETDATE()
    FROM Shipments
END;
GO
EXEC fillShipmentFacts;