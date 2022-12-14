module Parse.Bibtex (parseBibtex) where
import Entry (Entry (..), fromFields)
import Field (Field (Author))
import BibtexType (BibtexType)
import Data.Map (fromList, Map, lookup)
import Data.Maybe (catMaybes)
import Data.List.Split (splitOn)
import Text.Megaparsec (Parsec, ParseError, ParseErrorBundle, parse, many, between, endBy, noneOf, satisfy, parseTest, some, manyTill, choice, (<?>), anySingleBut, sepBy, MonadParsec (eof))
import Text.Megaparsec.Char (char, string, space, alphaNumChar, printChar, newline)
import Text.ParserCombinators.ReadP (many1)
import Text.Megaparsec.Char.Lexer (charLiteral)
import Data.Void (Void)

type Parser = Parsec Void String

parseBibtex :: String -> Either (ParseErrorBundle String Void) [Entry]
parseBibtex = parse parseBibtexFile "bibtex"

parseBibtexFile :: Parser [Entry]
parseBibtexFile = many parseEntry

-- TODO on entry parse error, skip verbosely
parseEntry :: Parser Entry
parseEntry = do
  many newline
  char '@'
  bibtexType <- parseBibtexType
  (key, fields) <- parseFields
  case Data.Map.lookup Author fields of
    -- TODO should this fail? An empty list may be better, possibly with warning
    Nothing -> fail "No 'author' field"
    Just authors -> return $ fromFields fields (splitOn " and " authors) bibtexType key

parseFields :: Parser (String, Map Field String)
parseFields = between (char '{') (char '}') $ do
  key <- parseKey <?> "valid key"
  char '\n'
  fields <- sepBy parseField (string ",\n")
  space
  return (key, fromList fields)

parseField :: Parser (Field, String)
parseField = do
  field <- space >> choice validFields <?> "valid field"
  value <- space >> char '=' >> space >> char '{' >> some (anySingleBut '}') <?> ("value for field " ++ field)
  char '}'
  return (read field, value)
  where
    validFields =
      [ string "abstract"
      , string "annote"
      , string "address"
      , string "author"
      , string "booktitle"
      , string "chapter"
      , string "crossref"
      , string "doi"
      , string "edition"
      , string "editor"
      , string "howpublished"
      , string "institution"
      , string "issn"
      , string "issue"
      , string "journal"
      , string "keywords"
      , string "month"
      , string "note"
      , string "number"
      , string "organization"
      , string "pages"
      , string "publisher"
      , string "school"
      , string "series"
      , string "title"
      , string "type"
      , string "volume"
      , string "year"
      ]

parseKey :: Parser String
parseKey = manyTill charLiteral (char ',') <?> "key"

parseBibtexType :: Parser BibtexType
parseBibtexType =
  fmap read (choice validBibtexTypes) <?> "valid type"
  where
    validBibtexTypes =
      [ string "article"
      , string "book"
      , string "booklet"
      , string "conference"
      , string "inbook"
      , string "incollection"
      , string "inproceedings"
      , string "manual"
      , string "mastersthesis"
      , string "misc"
      , string "phdthesis"
      , string "proceedings"
      , string "techreport"
      , string "unpublished"
      ]

splitAuthors :: Maybe String -> [String]
splitAuthors Nothing = []
splitAuthors (Just s) = splitOn " and " s
