USE [TailspinToys_Demo_Final]
GO

/****** Objekt:  StoredProcedure [dbo].[usp_PurchaseSpaceRanger]    Skriptdatum: 23.06.2026 10:47:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE   PROC [dbo].[usp_PurchaseSpaceRanger]
  @CustomerName nvarchar(200),
  @Email        nvarchar(320),
  @Amount       INT   -- If this is quantity, consider INT instead
AS
BEGIN
  SET NOCOUNT ON;

      DECLARE @SQLCMD_TEMPLATE NVARCHAR(MAX)
      DECLARE @SQLCMD NVARCHAR(MAX)
      DECLARE @DBID INT
      DECLARE @DBNAME NVARCHAR(100)
      
      SET @SQLCMD_TEMPLATE = '
    BEGIN TRAN;

    DECLARE @CustomerId       int;
    DECLARE @ProductId        int;
    DECLARE @Price            decimal(9,2) = 49.99;
    DECLARE @DiscountAmount   decimal(9,2) = 10.00;
    DECLARE @CustomerStateID  int;
 
    -- Pick product
    SELECT TOP (1)
      @ProductId = ProductId
    FROM [##db-name##].dbo.Product
    WHERE ProductName LIKE ''%Fabric Space Ranger%'';
 
    IF @ProductId IS NULL
      THROW 50001, ''Product not found (Fabric Space Ranger).'', 1;
 
    -- Random state id 1..51
    SET @CustomerStateID = 1 + ABS(CHECKSUM(NEWID())) % 51;
 
    -- Insert customer
    INSERT INTO [##db-name##].dbo.Customer (CustomerName, Email,Country,DateCreated)
    VALUES (@CustomerName, @Email,''MicroHack'', GETDATE());
 
    SET @CustomerId = SCOPE_IDENTITY();
 
    -- Insert sales row
    INSERT INTO [##db-name##].dbo.Sales
      (OrderDate, ShipDate, CustomerStateID, ProductID, Quantity, UnitPrice,
       DiscountAmount, PromotionCode, CustomerID, TotalPrice)
    VALUES
      (GETDATE(), NULL,
       @CustomerStateID,
       @ProductId,
       @Amount,
       @Price,
       @DiscountAmount,
       ''LaunchDay'',
       @CustomerId,
       (@Price - @DiscountAmount) * @Amount);
 
    COMMIT;'
 SET @DBNAME = 'TailspinToys_Demo_Final'
      IF EXISTS (SELECT * FROM sys.databases WHERE name = @DBNAME)
      BEGIN
            SET @SQLCMD = REPLACE(@SQLCMD_TEMPLATE,'##db-name##',@DBNAME)
            BEGIN TRY
                  EXECUTE sp_executesql @SQLCMD, N'@CustomerName NVARCHAR(200), @Email NVARCHAR(320), @Amount INT', @CustomerName=@CustomerName,@Email=@Email,@Amount=@Amount
            END TRY
            BEGIN CATCH
                  PRINT ERROR_MESSAGE()
                  ROLLBACK
            END CATCH
      END




SET @DBID = 1
WHILE @DBID <= 100
BEGIN
      SET @DBNAME = 'TailspinToys_User' + RIGHT('000' + CAST(@DBID AS NVARCHAR(3)),3)
      IF EXISTS (SELECT * FROM sys.databases WHERE name = @DBNAME)
      BEGIN
            SET @SQLCMD = REPLACE(@SQLCMD_TEMPLATE,'##db-name##',@DBNAME)
            BEGIN TRY
                  EXECUTE sp_executesql @SQLCMD, N'@CustomerName NVARCHAR(200), @Email NVARCHAR(320), @Amount INT', @CustomerName=@CustomerName,@Email=@Email,@Amount=@Amount
            END TRY
            BEGIN CATCH
                  PRINT ERROR_MESSAGE()
                  ROLLBACK
            END CATCH
      END
      SET @DBID = @DBID + 1
END
END;
GO


