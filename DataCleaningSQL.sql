/*
In this project, I cleaned raw data from the Nashville housing market to be used for further analysis. 

Cleaning Tasks
1. Remove duplicated rows
2. Populate PropertyAddress data where fields were null
3. Breakout the PropertyAddress and OwnerAddress fields from a single column to multiple 
   columns for each address component (address, city, state)
4. Standardize the SoldAsVacant fields from 'Yes', 'No', 'Y', and 'N' to just 'N' and 'Y'
5. Covert SoldDate fields from Datetime to Date
6. Remove unused columns
*/

/*########################################################################################################################
Remove duplicated rows
########################################################################################################################*/
--1. Identify duplicate rows
SELECT
	*,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
	) row_num
FROM
	Projects.dbo.NashvilleHousing
ORDER BY row_num DESC

--2. Isolate duplicate rows
WITH RowNumCTE AS (
	SELECT
		*,
		ROW_NUMBER() OVER (
		PARTITION BY ParcelID,
					 PropertyAddress,
					 SaleDate,
					 LegalReference
					 ORDER BY
						UniqueID
		) row_num
	FROM
		Projects.dbo.NashvilleHousing
)
SELECT
*
FROM
	RowNumCTE
WHERE
	row_num > 1
ORDER BY PropertyAddress

--3. Delete duplicates
WITH RowNumCTE AS (
	SELECT
		*,
		ROW_NUMBER() OVER (
		PARTITION BY ParcelID,
					 PropertyAddress,
					 SaleDate,
					 LegalReference
					 ORDER BY
						UniqueID
		) row_num
	FROM
		Projects.dbo.NashvilleHousing
)
DELETE
FROM
	RowNumCTE
WHERE
	row_num > 1

--4. Verify all duplicates were deleted using query 2

/*########################################################################################################################
Populate PropertyAddress data where fields were null
########################################################################################################################*/
--1. Assess data
SELECT 
	*
FROM
	Projects.dbo.NashvilleHousing
WHERE
	PropertyAddress IS NULL;

--2. Identify that the ParcelID will always correlate to the same PropertyAddress
WITH cte as (                       
	SELECT 
		COUNT(ParcelID) OVER (
			PARTITION BY ParcelID
		) CountParcelID,
		*
	FROM
		Projects.dbo.NashvilleHousing
)
SELECT *
FROM cte
WHERE cte.CountParcelID > 1
ORDER BY cte.ParcelID;

--3. Self join using the ParcelID and check if there is an available address for each null row
SELECT
	a.ParcelID,
	a.PropertyAddress,
	b.ParcelID,
	b.PropertyAddress
FROM
	Projects.dbo.NashvilleHousing a
JOIN Projects.dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL;

--3. Update null values
UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM
	Projects.dbo.NashvilleHousing a
JOIN Projects.dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL;
	
/*########################################################################################################################
Breaking out PropertyAddress and OwnerAddress fields into Individual Columns (Address, City, State)
########################################################################################################################*/
--SUBSTRING method
--1. Assess data
SELECT 
	PropertyAddress
FROM
	Projects.dbo.NashvilleHousing

--2. Testing
SELECT 
	SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1) AS Address,
	SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress)) AS City
FROM
	Projects.dbo.NashvilleHousing

--3. Add new columns for split values
ALTER TABLE 
	Projects.dbo.NashvilleHousing
ADD
	PropertySplitAddress nvarchar(255),
	PropertySplitCity nvarchar(255);

--4. Insert data
UPDATE
	Projects.dbo.NashvilleHousing
SET
	PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1),
	PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress));

--5. Verify updates
SELECT
	PropertyAddress,
	PropertySplitAddress,
	PropertySplitCity
FROM
	Projects.dbo.NashvilleHousing

-- REPLACE & PARSENAME method
--1. Assess Data
SELECT
	OwnerAddress
FROM
	Projects.dbo.NashvilleHousing

--2. Use replace and parsename functions to breakout address
SELECT
	PARSENAME(REPLACE(OwnerAddress, ',','.'), 3) AS Address,
	PARSENAME(REPLACE(OwnerAddress, ',','.'), 2) AS City,
	PARSENAME(REPLACE(OwnerAddress, ',','.'), 1) AS State
FROM
	Projects.dbo.NashvilleHousing

--3. Add new columns
ALTER TABLE 
	Projects.dbo.NashvilleHousing
ADD
	OwnerSplitAddress nvarchar(255),
	OwnerSplitCity nvarchar(255),
	OwnerSplitState nvarchar(255)

--4. Insert data
UPDATE
	Projects.dbo.NashvilleHousing
SET
	OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',','.'), 3),
	OwnerSplitCity    = PARSENAME(REPLACE(OwnerAddress, ',','.'), 2),
	OwnerSplitState  =  PARSENAME(REPLACE(OwnerAddress, ',','.'), 1)

--5. Verify
SELECT
	OwnerAddress,
	OwnerSplitAddress,
	OwnerSplitCity,
	OwnerSplitState
FROM
	Projects.dbo.NashvilleHousing

/*########################################################################################################################
Standardize the SoldAsVacant fields from 'Yes', 'No', 'Y', and 'N' to just 'N' and 'Y'
########################################################################################################################*/
--1. Assess data

SELECT
	DISTINCT(SoldAsVacant)
FROM
	Projects.dbo.NashvilleHousing

--2. Test Solution
SELECT
	SoldAsVacant,
	CASE 
		WHEN SoldAsVacant = 'Yes' THEN 'Y'
		WHEN SoldAsVacant = 'No' THEN 'N'
		ELSE SoldAsVacant
	END
FROM
	Projects.dbo.NashvilleHousing

--3. Standardize values
UPDATE Projects.dbo.NashvilleHousing
SET	SoldAsVacant =
	CASE 
		WHEN SoldAsVacant = 'Yes' THEN 'Y'
		WHEN SoldAsVacant = 'No' THEN 'N'
		ELSE SoldAsVacant
	END;

--4. Verify using query 1

/*########################################################################################################################
Convert the SoldDate fields from Datetime to Date
########################################################################################################################*/

--1. Assess data
SELECT
    SaleDate,
    CONVERT(date, SaleDate)
FROM
	Projects.dbo.NashvilleHousing

--2. Create new column
ALTER TABLE 
	Projects.dbo.NashvilleHousing
ADD
	StandardSaleDate date;

--3. Populate data
UPDATE
	Projects.dbo.NashvilleHousing
SET
	StandardSaleDate = CONVERT(date, SaleDate)

--4. Verify
SELECT
    SaleDate,
    CONVERT(date, SaleDate)
    StandardSaleDate
FROM
	Projects.dbo.NashvilleHousing

/*########################################################################################################################
Remove unused columns
########################################################################################################################*/

ALTER TABLE	Projects.dbo.NashvilleHousing
DROP COLUMN
	PropertyAddress,
	OwnerAddress
	SaleDate
