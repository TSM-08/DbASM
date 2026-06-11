-- Essential indexes for final_check.sql performance
-- Apply to both src and trg schemas

CREATE INDEX IX_metadata_01_object ON src.metadata_01 (object_type);
CREATE INDEX IX_metadata_01_object ON trg.metadata_01 (object_type);
/