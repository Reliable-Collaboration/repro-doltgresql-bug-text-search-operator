-- A document as a tsvector.
SELECT to_tsvector('english', 'fat cats');

-- A query as a tsquery.
SELECT to_tsquery('english', 'cat');

-- The two matched with the @@ operator.
SELECT to_tsvector('english', 'fat cats')
       @@ to_tsquery('english', 'cat');

-- The @@ operator between two text values.
SELECT 'fat cats' @@ 'cat';
