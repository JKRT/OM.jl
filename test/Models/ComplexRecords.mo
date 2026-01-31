/*
Models that demonstrate complex record types in Modelica.
*/

package ComplexRecords

// A model demonstrating nested records and arrays.
model ComplexRecord1

  record R1
    Real x;
    Real y;
  end R1;

  record R2
    R1[2] innerRecords;
    Real z(start = 0);
  end R2;

  // Instance of the complex record
  R2 myRecord;
equation
    // Example equations using the record fields
    myRecord.innerRecords[1].x = 1.0;
    myRecord.innerRecords[1].y = 2.0;
    myRecord.innerRecords[2].x = 3.0;
    myRecord.innerRecords[2].y = 4.0;
    der(myRecord.z) = 5.0 + time;
end ComplexRecord1;


model ComplexRecord2
    record MixedRecord
      Integer id;
      Real values[3];
      Boolean flag;
      String description;
    end MixedRecord;

  // Instance of the mixed record
  MixedRecord dataRecord1;
  MixedRecord dataRecord2;
equation
    // Example equations using the record fields
    dataRecord1.id = 1;
    dataRecord1.values = {1.0, 2.0, 3.0};
    dataRecord1.flag = true;
    dataRecord1.description = "First record";

    dataRecord2.id = 2;
    dataRecord2.values = {4.0, 5.0, 6.0};
    dataRecord2.flag = false;
    dataRecord2.description = "Second record";

end ComplexRecord2;


end ComplexRecords;
