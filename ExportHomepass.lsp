(defun get-geolocation-info ()
  ;; Try to get the 'GEODATUMPOINT' system variable
  (setq geoPoint (getvar "GEODATUMPOINT"))

  ;; If geoPoint is valid and a list with 2 elements, return it as latitude and longitude data
  (if (and geoPoint (listp geoPoint) (= (length geoPoint) 2))
    (progn
      (princ (strcat "\nGeolocation found: Latitude " (rtos (car geoPoint) 2 6) ", Longitude " (rtos (cadr geoPoint) 2 6)))
      (list (car geoPoint) (cadr geoPoint))  ;; Latitude and Longitude
    )
    (progn
      (princ "\nWarning: No geolocation information available.")
      nil  ;; If no geolocation, return nil
    )
  )
)

(defun utm-to-latlon (utmX utmY zone hemisphere)
  ;; Mock-up function for converting UTM to Latitude/Longitude.
  ;; Add the actual conversion implementation if necessary.
  ;; For now, we return mock-up coordinates.

  ;; Conversion logic from UTM to Latitude/Longitude should be added here.
  ;; Hemisphere can be used to determine whether coordinates are in the northern or southern hemisphere.
  
  (list (+ utmX 0.001) (+ utmY 0.001))  ;; Dummy latitude and longitude values as placeholders
)

(defun c:ExportHomepass ()
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq groupList (list))  ;; List to store group info
  (setq groupCounter 0)    ;; Counter for folder numbering

  ;; Get input from the user to replace 'X' with a chosen letter
  (setq userChar (getstring "\nEnter a letter to replace 'X' (example: A, B, C): "))

  ;; Validate user input
  (if (not (wcmatch userChar "[A-Z]"))
    (progn
      (princ "\nError: Please enter a single uppercase letter (A-Z).")
      (exit)
    )
  )

  ;; Get geolocation information
  (setq geo-info (get-geolocation-info))
  (if geo-info
    (progn
      ;; Extract the base point and coordinate system
      (setq base-point (car geo-info))  ;; Latitude
      (setq coordinate-system (cadr geo-info))  ;; Longitude
    )
    (progn
      (princ "\nWarning: No geolocation information available. Using original UTM coordinates.")
      (setq base-point nil)  ;; No base point, proceed with original UTM
    )
  )

  ;; Function to create a two-digit formatted number
  (defun format-counter (counter)
    (if (< counter 10)
      (strcat "0" (itoa counter))  ;; Add 0 in front if < 10
      (itoa counter)               ;; If >= 10, use the number as is
    )
  )

  ;; Loop to allow multiple group selections
  (while (setq groupSel (ssget ":S" '((0 . "TEXT"))))  ;; Select a group of text objects
    (setq groupCounter (1+ groupCounter))  ;; Increment the group counter
    (setq groupName (strcat "FAT " userChar (format-counter groupCounter)))  ;; Create folder name in the format "FAT X01", "FAT X02", etc.

    ;; Initialize an empty list to store text info for this group
    (setq textList (list))

    ;; Iterate through the selected objects in the group
    (setq i 0)
    (while (< i (sslength groupSel))
      (setq textObj (vlax-ename->vla-object (ssname groupSel i)))  ;; Get the text object
      (setq textStr (vla-get-TextString textObj))  ;; Get the text string (marker name)
      (setq textPt (vlax-get textObj 'InsertionPoint))  ;; Get the insertion point (coordinates)

      ;; Convert from UTM to Latitude/Longitude using the geolocation base point
      (setq zone 49)  ;; Set the UTM zone for East Java (adjust as needed)
      (setq hemisphere "S")  ;; Set hemisphere (N for north, S for south)

      ;; If base point is unavailable, use the original UTM
      ;; (Add UTM to Latitude/Longitude conversion if needed)
      (if base-point
        (setq LL (utm-to-latlon (car textPt) (cadr textPt) zone hemisphere))  ;; If base point exists, apply UTM-to-LL conversion function
        (setq LL (list (car textPt) (cadr textPt)))  ;; If not, use original UTM
      )

      ;; Add to the list if LL is not nil (valid)
      (if LL
        (setq textList (append textList (list (list textStr LL))))
      )

      (setq i (1+ i))
    )

    ;; Save this group's text list and folder name in groupList
    (setq groupList (append groupList (list (cons groupName textList))))
  )

  ;; Create KML content
  (setq kmlContent "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n<Document>\n")

  ;; Iterate through each group in the selected order
  (foreach group groupList
    (setq groupName (car group))  ;; Get the folder name (group name)
    (setq kmlContent (strcat kmlContent "<Folder>\n<name>" groupName "</name>\n"))

    ;; Iterate through the text objects in the group
    (foreach textInfo (cdr group)
      (setq textStr (car textInfo))  ;; Get the text string
      (setq LL (cadr textInfo))  ;; Get the converted coordinates (latitude and longitude)
      (setq lat (rtos (car LL) 2 6))  ;; Latitude
      (setq lon (rtos (cadr LL) 2 6))  ;; Longitude

      ;; Add a placemark for each text object
      (setq kmlContent (strcat kmlContent "<Placemark>\n<name>" textStr "</name>\n<Point><coordinates>" lon "," lat ",0</coordinates></Point>\n</Placemark>\n"))
    )

    ;; Close folder tag
    (setq kmlContent (strcat kmlContent "</Folder>\n"))
  )

  ;; Complete the KML content
  (setq kmlContent (strcat kmlContent "</Document>\n</kml>"))

  ;; Write the KML file
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
