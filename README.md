# AutoCAD LISP Script - `ExportHomepass`

This LISP script is designed to work within AutoCAD to automate the process of exporting geographic location information from text objects and converting UTM (Universal Transverse Mercator) coordinates to Latitude/Longitude (Lat/Lon). The output of the process is saved as a KML file, which can be opened in mapping applications such as Google Earth.

## Functions Breakdown

### 1. `get-geolocation-info`
This function attempts to retrieve the geolocation base point from the AutoCAD system variable `GEODATUMPOINT`. If successful, it returns the latitude and longitude of the base point. If not, it returns `nil` and displays a warning message.
```lisp
(defun get-geolocation-info ()
  ;; Attempts to get the 'GEODATUMPOINT' system variable.
  (setq geoPoint (getvar "GEODATUMPOINT"))

  ;; If valid and contains 2 elements, return it as latitude and longitude.
  (if (and geoPoint (listp geoPoint) (= (length geoPoint) 2))
    (progn
      ;; Print the found geolocation in latitude and longitude format.
      (princ (strcat "\nGeolocation found: Latitude " (rtos (car geoPoint) 2 6) ", Longitude " (rtos (cadr geoPoint) 2 6)))
      (list (car geoPoint) (cadr geoPoint))
    )
    (progn
      ;; Print a warning message if no geolocation is found.
      (princ "\nWarning: No geolocation information available.")
      nil
    )
  )
)
```
- **Input:** None (Uses system variable `GEODATUMPOINT`).
- **Output:** A list containing the latitude and longitude or `nil` if unavailable.

### 2. `utm-to-latlon`
This function is a mock-up for converting UTM coordinates to Latitude and Longitude. Currently, it returns placeholder coordinates and can be replaced with a real UTM conversion algorithm if required.
```lisp
(defun utm-to-latlon (utmX utmY zone hemisphere)
  ;; Placeholder for UTM to Latitude/Longitude conversion logic.
  ;; Add actual conversion logic as needed.
  (list (+ utmX 0.001) (+ utmY 0.001))  ;; Dummy values for latitude and longitude
)
```
- **Input:** UTM coordinates (X, Y), zone number, and hemisphere.
- **Output:** Mock-up latitude and longitude values.

### 3. `format-counter`
This helper function takes a numeric counter and formats it as a two-digit string. It ensures that numbers less than 10 are preceded by a zero (e.g., `01`, `02`, etc.).
```lisp
(defun format-counter (counter)
  ;; If the counter is less than 10, add a leading zero.
  (if (< counter 10)
    (strcat "0" (itoa counter))
    (itoa counter)  ;; Otherwise, return the number as a string.
  )
)
```
- **Input:** A numeric counter.
- **Output:** A two-digit string.

### 4. `c:ExportHomepass`
This is the main function of the script. It allows users to export the selected text objects' coordinates (either in UTM or converted to Latitude/Longitude) into a KML file. This KML file can then be used in mapping software.
```lisp
(defun c:ExportHomepass ()
  ;; Set up the active AutoCAD document.
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))

  ;; Initialize variables.
  (setq groupList (list))  ;; Stores group information
  (setq groupCounter 0)    ;; Counter for numbering groups
  
  ;; Ask the user to input a letter to replace 'X' in the folder name.
  (setq userChar (getstring "\nEnter a letter to replace 'X' (example: A, B, C): "))

  ;; Validate that the input is a single capital letter (A-Z).
  (if (not (wcmatch userChar "[A-Z]"))
    (progn
      (princ "\nError: Please enter a single uppercase letter (A-Z).")
      (exit)
    )
  )

  ;; Retrieve geolocation information if available.
  (setq geo-info (get-geolocation-info))
  (if geo-info
    (progn
      (setq base-point (car geo-info))  ;; Latitude (if available)
      (setq coordinate-system (cadr geo-info))  ;; Longitude (if available)
    )
    (progn
      (princ "\nWarning: No geolocation information available. Using original UTM coordinates.")
      (setq base-point nil)  ;; If no geolocation, proceed with UTM.
    )
  )

  ;; Loop to allow multiple group selections.
  (while (setq groupSel (ssget ":S" '((0 . "TEXT"))))  ;; Select a group of text objects.
    (setq groupCounter (1+ groupCounter))  ;; Increment the group counter.
    (setq groupName (strcat "FAT " userChar (format-counter groupCounter)))  ;; Folder name format "FAT X01", "FAT X02", etc.
    (setq textList (list))  ;; List for text objects in this group.

    ;; Loop through selected text objects.
    (setq i 0)
    (while (< i (sslength groupSel))
      (setq textObj (vlax-ename->vla-object (ssname groupSel i)))  ;; Get the text object.
      (setq textStr (vla-get-TextString textObj))  ;; Get the text string (marker name).
      (setq textPt (vlax-get textObj 'InsertionPoint))  ;; Get the insertion point (coordinates).

      ;; Define UTM zone and hemisphere.
      (setq zone 49)  ;; UTM zone for East Java.
      (setq hemisphere "S")  ;; Southern hemisphere.

      ;; Convert UTM to Latitude/Longitude if a base point is available, otherwise use UTM.
      (if base-point
        (setq LL (utm-to-latlon (car textPt) (cadr textPt) zone hemisphere))
        (setq LL (list (car textPt) (cadr textPt)))
      )

      ;; Append the text information and coordinates to the list.
      (if LL
        (setq textList (append textList (list (list textStr LL))))
      )

      (setq i (1+ i))
    )

    ;; Add the group name and text list to the overall group list.
    (setq groupList (append groupList (list (cons groupName textList))))
  )

  ;; Create the KML content as a string.
  (setq kmlContent "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n<Document>\n")

  ;; Iterate through each group to add it to the KML content.
  (foreach group groupList
    (setq groupName (car group))  ;; Get the folder name.
    (setq kmlContent (strcat kmlContent "<Folder>\n<name>" groupName "</name>\n"))

    ;; Add each text object and its coordinates to the KML.
    (foreach textInfo (cdr group)
      (setq textStr (car textInfo))  ;; Get the text string.
      (setq LL (cadr textInfo))  ;; Get the converted coordinates.
      (setq lat (rtos (car LL) 2 6))  ;; Latitude.
      (setq lon (rtos (cadr LL) 2 6))  ;; Longitude.

      ;; Add a placemark for the text object.
      (setq kmlContent (strcat kmlContent "<Placemark>\n<name>" textStr "</name>\n<Point><coordinates>" lon "," lat ",0</coordinates></Point>\n</Placemark>\n"))
    )

    ;; Close the folder tag in the KML.
    (setq kmlContent (strcat kmlContent "</Folder>\n"))
  )

  ;; Finalize the KML content.
  (setq kmlContent (strcat kmlContent "</Document>\n</kml>"))

  ;; Save the KML file to the location specified by the user.
  (setq kmlFileName (getfiled "Save KML As" "" "kml" 1))
  (if kmlFileName
    (progn
      (setq kmlFile (open kmlFileName "w"))
      (write-line kmlContent kmlFile)
      (close kmlFile)
      (princ (strcat "\nKML file successfully saved at: " kmlFileName))
    )
    (princ "\nError: Unable to save the KML file.")
  )
  (princ)
)
```

### Key Points:
1. **Geolocation:** If available, the script retrieves geolocation data, which is essential for converting UTM coordinates to Latitude/Longitude.
2. **Text Object Selection:** Users select text objects, which are interpreted as markers with associated coordinates.
3. **Conversion:** If a base point is available, UTM coordinates are converted to Lat/Lon. If not, UTM coordinates are used directly.
4. **KML Output:** The script generates a KML file, which can be used to visualize

 the selected points on mapping platforms like Google Earth.

---

