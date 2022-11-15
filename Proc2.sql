--1
--1.1 Scalar function to convert a terminal code into the location for that terminal (City, State)
CREATE FUNCTION convTerm
	(@Terminal CHAR(3))
	RETURNS VARCHAR(28)
AS
BEGIN
	RETURN (SELECT CONCAT(TerminalCity, ', ',TerminalState) 
			FROM Terminals
			WHERE @Terminal = TerminalCode
	);
END;
GO
--Test the function
SELECT dbo.convTerm(TerminalCode) FROM Terminals;

--1.2 Convert CarrierID into CarrierName
CREATE FUNCTION convCarrierID
	(@CarrierID INT)
	RETURNS VARCHAR(20)
AS
BEGIN
	RETURN (SELECT CarrierName 
			FROM Carriers
			WHERE @CarrierID = CarrierID
	);
END;
GO
--Test Function
SELECT dbo.convCarrierID(CarrierID) FROM Carriers;

--1.3 Convert VIN to make, model of the truck in a single string
CREATE FUNCTION convVin
	(@VIN CHAR(17))
	RETURNS VARCHAR(57)
AS
BEGIN
	RETURN (SELECT CONCAT(Manufacturer, ', ', Model)
			FROM Trucks
			WHERE @VIN = VIN
	);
END;
GO

--Test frunction
SELECT dbo.convVin(VIN) FROM Trucks;

--2. Query to display a complex string with information from the 3 functions above.
SELECT CONCAT('Shipment number ', dwShipmentFacts.ShipmentID, ' departed from ', dbo.convTerm(dwShipmentFacts.OriginTerminal), 
			  ' and arrived in ', dbo.convTerm(dwShipmentFacts.DestinationTerminal), ' on ', dwShipmentFacts.ArrivalDateTime, '. ', 
			  dbo.convCarrierID(dwShipmentFacts.CarrierID), ' delivered the shipment using a ', dbo.convVin(dwShipmentFacts.VIN), '.')
FROM dwShipmentFacts 
WHERE ArrivalDateTime < getDate();


--3. Trigger that updates the LastServiceDate in the dwTrucksDim from the DB
CREATE TRIGGER uDateLSD ON Trucks
AFTER UPDATE
AS 
BEGIN
	UPDATE dwTrucksDim
	SET LastServiceDate = Trucks.LastServiceDate
	FROM Trucks
	WHERE dwTrucksDim.VIN = Trucks.VIN
	AND dwTrucksDim.LastServiceDate != Trucks.LastServiceDate;

	UPDATE dwTrucksDim
	SET ServiceStatus = 
		CASE
			WHEN DATEDIFF(d,LastServiceDate,getDate()) > 45 THEN 'Review Service'
			ELSE 'Current'
		END;
	;
END;
GO

--4. Test upDateLSD
--4.1 Current Truck
UPDATE Trucks
SET LastServiceDate = '11/9/2022'
WHERE VIN = '1FAFP42X24F175608';

--4.2 Review Service Truck
UPDATE Trucks
SET LastServiceDate = '1/12/2022'
WHERE VIN = '1FDNF21S42ED09150';

--5 Query the two trucks that were changed above
SELECT * FROM dwTrucksDim
WHERE VIN IN ('1FDNF21S42ED09150', '1FAFP42X24F175608');


--Side note: Dr. North, I made the function below but could not get the data to be written into dwTrucksDim when using onse UPDATE statement. What is wrong with it? 
--I spent hours looking at it and tweaking it, but never got it to work. 
ALTER TRIGGER upDateLSD ON Trucks
AFTER UPDATE
AS
BEGIN
	UPDATE dwTrucksDim
	SET dwTrucksDim.LastServiceDate = INSERTED.LastServiceDate,
		ServiceStatus =
			CASE
				WHEN DATEDIFF(d,dwTrucksDim.LastServiceDate,GetDate()) > 45 THEN 'Review Service'
				ELSE 'Current'
			END
	FROM INSERTED
	WHERE dwTrucksDim.LastServiceDate NOT IN (SELECT LastServiceDate FROM Trucks);
END;
GO