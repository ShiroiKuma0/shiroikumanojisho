// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDictionaryEntryCollection on Isar {
  IsarCollection<DictionaryEntry> get dictionaryEntrys => this.collection();
}

const DictionaryEntrySchema = CollectionSchema(
  name: r'DictionaryEntry',
  id: 433168435156867289,
  properties: {
    r'audioPaths': PropertySchema(
      id: 0,
      name: r'audioPaths',
      type: IsarType.stringList,
    ),
    r'compressedDefinitions': PropertySchema(
      id: 1,
      name: r'compressedDefinitions',
      type: IsarType.byteList,
    ),
    r'dictionaryId': PropertySchema(
      id: 2,
      name: r'dictionaryId',
      type: IsarType.long,
    ),
    r'entryTagsRaw': PropertySchema(
      id: 3,
      name: r'entryTagsRaw',
      type: IsarType.string,
    ),
    r'hashCode': PropertySchema(id: 4, name: r'hashCode', type: IsarType.long),
    r'headingTagsRaw': PropertySchema(
      id: 5,
      name: r'headingTagsRaw',
      type: IsarType.string,
    ),
    r'imagePaths': PropertySchema(
      id: 6,
      name: r'imagePaths',
      type: IsarType.stringList,
    ),
    r'popularity': PropertySchema(
      id: 7,
      name: r'popularity',
      type: IsarType.double,
    ),
    r'reading': PropertySchema(id: 8, name: r'reading', type: IsarType.string),
    r'term': PropertySchema(id: 9, name: r'term', type: IsarType.string),
    r'termLength': PropertySchema(
      id: 10,
      name: r'termLength',
      type: IsarType.long,
    ),
  },

  estimateSize: _dictionaryEntryEstimateSize,
  serialize: _dictionaryEntrySerialize,
  deserialize: _dictionaryEntryDeserialize,
  deserializeProp: _dictionaryEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'term': IndexSchema(
      id: 5114652110782333408,
      name: r'term',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'term',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'reading': IndexSchema(
      id: -8872607090340677149,
      name: r'reading',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'reading',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'termLength': IndexSchema(
      id: 3077462675055986876,
      name: r'termLength',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'termLength',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'dictionaryId': IndexSchema(
      id: 3926511253275933290,
      name: r'dictionaryId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'dictionaryId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'dictionaryId_term': IndexSchema(
      id: 4108575498810091711,
      name: r'dictionaryId_term',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'dictionaryId',
          type: IndexType.value,
          caseSensitive: false,
        ),
        IndexPropertySchema(
          name: r'term',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _dictionaryEntryGetId,
  getLinks: _dictionaryEntryGetLinks,
  attach: _dictionaryEntryAttach,
  version: '3.3.2',
);

int _dictionaryEntryEstimateSize(
  DictionaryEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final list = object.audioPaths;
    if (list != null) {
      bytesCount += 3 + list.length * 3;
      {
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          bytesCount += value.length * 3;
        }
      }
    }
  }
  bytesCount += 3 + object.compressedDefinitions.length;
  bytesCount += 3 + object.entryTagsRaw.length * 3;
  bytesCount += 3 + object.headingTagsRaw.length * 3;
  {
    final list = object.imagePaths;
    if (list != null) {
      bytesCount += 3 + list.length * 3;
      {
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          bytesCount += value.length * 3;
        }
      }
    }
  }
  bytesCount += 3 + object.reading.length * 3;
  bytesCount += 3 + object.term.length * 3;
  return bytesCount;
}

void _dictionaryEntrySerialize(
  DictionaryEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.audioPaths);
  writer.writeByteList(offsets[1], object.compressedDefinitions);
  writer.writeLong(offsets[2], object.dictionaryId);
  writer.writeString(offsets[3], object.entryTagsRaw);
  writer.writeLong(offsets[4], object.hashCode);
  writer.writeString(offsets[5], object.headingTagsRaw);
  writer.writeStringList(offsets[6], object.imagePaths);
  writer.writeDouble(offsets[7], object.popularity);
  writer.writeString(offsets[8], object.reading);
  writer.writeString(offsets[9], object.term);
  writer.writeLong(offsets[10], object.termLength);
}

DictionaryEntry _dictionaryEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DictionaryEntry(
    audioPaths: reader.readStringList(offsets[0]),
    compressedDefinitions: reader.readByteList(offsets[1]) ?? [],
    dictionaryId: reader.readLong(offsets[2]),
    entryTagsRaw: reader.readStringOrNull(offsets[3]) ?? '',
    headingTagsRaw: reader.readStringOrNull(offsets[5]) ?? '',
    id: id,
    imagePaths: reader.readStringList(offsets[6]),
    popularity: reader.readDouble(offsets[7]),
    reading: reader.readString(offsets[8]),
    term: reader.readString(offsets[9]),
  );
  return object;
}

P _dictionaryEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset)) as P;
    case 1:
      return (reader.readByteList(offset) ?? []) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 6:
      return (reader.readStringList(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _dictionaryEntryGetId(DictionaryEntry object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _dictionaryEntryGetLinks(DictionaryEntry object) {
  return [];
}

void _dictionaryEntryAttach(
  IsarCollection<dynamic> col,
  Id id,
  DictionaryEntry object,
) {
  object.id = id;
}

extension DictionaryEntryQueryWhereSort
    on QueryBuilder<DictionaryEntry, DictionaryEntry, QWhere> {
  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhere> anyTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'term'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhere> anyReading() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'reading'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhere> anyTermLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'termLength'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhere>
  anyDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'dictionaryId'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhere>
  anyDictionaryIdTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'dictionaryId_term'),
      );
    });
  }
}

extension DictionaryEntryQueryWhere
    on QueryBuilder<DictionaryEntry, DictionaryEntry, QWhereClause> {
  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause> termEqualTo(
    String term,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'term', value: [term]),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termNotEqualTo(String term) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'term',
                lower: [],
                upper: [term],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'term',
                lower: [term],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'term',
                lower: [term],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'term',
                lower: [],
                upper: [term],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termGreaterThan(String term, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'term',
          lower: [term],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termLessThan(String term, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'term',
          lower: [],
          upper: [term],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause> termBetween(
    String lowerTerm,
    String upperTerm, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'term',
          lower: [lowerTerm],
          includeLower: includeLower,
          upper: [upperTerm],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termStartsWith(String TermPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'term',
          lower: [TermPrefix],
          upper: ['$TermPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'term', value: ['']),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'term', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'term', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'term', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'term', upper: ['']),
            );
      }
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  readingEqualTo(String reading) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'reading', value: [reading]),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  readingNotEqualTo(String reading) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'reading',
                lower: [],
                upper: [reading],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'reading',
                lower: [reading],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'reading',
                lower: [reading],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'reading',
                lower: [],
                upper: [reading],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  readingGreaterThan(String reading, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'reading',
          lower: [reading],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  readingLessThan(String reading, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'reading',
          lower: [],
          upper: [reading],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  readingBetween(
    String lowerReading,
    String upperReading, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'reading',
          lower: [lowerReading],
          includeLower: includeLower,
          upper: [upperReading],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  readingStartsWith(String ReadingPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'reading',
          lower: [ReadingPrefix],
          upper: ['$ReadingPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  readingIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'reading', value: ['']),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  readingIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'reading', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'reading', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'reading', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'reading', upper: ['']),
            );
      }
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termLengthEqualTo(int termLength) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'termLength', value: [termLength]),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termLengthNotEqualTo(int termLength) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'termLength',
                lower: [],
                upper: [termLength],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'termLength',
                lower: [termLength],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'termLength',
                lower: [termLength],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'termLength',
                lower: [],
                upper: [termLength],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termLengthGreaterThan(int termLength, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'termLength',
          lower: [termLength],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termLengthLessThan(int termLength, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'termLength',
          lower: [],
          upper: [termLength],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  termLengthBetween(
    int lowerTermLength,
    int upperTermLength, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'termLength',
          lower: [lowerTermLength],
          includeLower: includeLower,
          upper: [upperTermLength],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdEqualTo(int dictionaryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'dictionaryId',
          value: [dictionaryId],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdNotEqualTo(int dictionaryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId',
                lower: [],
                upper: [dictionaryId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId',
                lower: [dictionaryId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId',
                lower: [dictionaryId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId',
                lower: [],
                upper: [dictionaryId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdGreaterThan(int dictionaryId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId',
          lower: [dictionaryId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdLessThan(int dictionaryId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId',
          lower: [],
          upper: [dictionaryId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdBetween(
    int lowerDictionaryId,
    int upperDictionaryId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId',
          lower: [lowerDictionaryId],
          includeLower: includeLower,
          upper: [upperDictionaryId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdEqualToAnyTerm(int dictionaryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'dictionaryId_term',
          value: [dictionaryId],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdNotEqualToAnyTerm(int dictionaryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId_term',
                lower: [],
                upper: [dictionaryId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId_term',
                lower: [dictionaryId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId_term',
                lower: [dictionaryId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId_term',
                lower: [],
                upper: [dictionaryId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdGreaterThanAnyTerm(int dictionaryId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId_term',
          lower: [dictionaryId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdLessThanAnyTerm(int dictionaryId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId_term',
          lower: [],
          upper: [dictionaryId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdBetweenAnyTerm(
    int lowerDictionaryId,
    int upperDictionaryId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId_term',
          lower: [lowerDictionaryId],
          includeLower: includeLower,
          upper: [upperDictionaryId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdTermEqualTo(int dictionaryId, String term) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'dictionaryId_term',
          value: [dictionaryId, term],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdEqualToTermNotEqualTo(int dictionaryId, String term) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId_term',
                lower: [dictionaryId],
                upper: [dictionaryId, term],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId_term',
                lower: [dictionaryId, term],
                includeLower: false,
                upper: [dictionaryId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId_term',
                lower: [dictionaryId, term],
                includeLower: false,
                upper: [dictionaryId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dictionaryId_term',
                lower: [dictionaryId],
                upper: [dictionaryId, term],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdEqualToTermGreaterThan(
    int dictionaryId,
    String term, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId_term',
          lower: [dictionaryId, term],
          includeLower: include,
          upper: [dictionaryId],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdEqualToTermLessThan(
    int dictionaryId,
    String term, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId_term',
          lower: [dictionaryId],
          upper: [dictionaryId, term],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdEqualToTermBetween(
    int dictionaryId,
    String lowerTerm,
    String upperTerm, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId_term',
          lower: [dictionaryId, lowerTerm],
          includeLower: includeLower,
          upper: [dictionaryId, upperTerm],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdEqualToTermStartsWith(int dictionaryId, String TermPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dictionaryId_term',
          lower: [dictionaryId, TermPrefix],
          upper: [dictionaryId, '$TermPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdEqualToTermIsEmpty(int dictionaryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'dictionaryId_term',
          value: [dictionaryId, ''],
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterWhereClause>
  dictionaryIdEqualToTermIsNotEmpty(int dictionaryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(
                indexName: r'dictionaryId_term',
                upper: [''],
              ),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'dictionaryId_term',
                lower: [''],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'dictionaryId_term',
                lower: [''],
              ),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(
                indexName: r'dictionaryId_term',
                upper: [''],
              ),
            );
      }
    });
  }
}

extension DictionaryEntryQueryFilter
    on QueryBuilder<DictionaryEntry, DictionaryEntry, QFilterCondition> {
  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'audioPaths'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'audioPaths'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'audioPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'audioPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'audioPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'audioPaths',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'audioPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'audioPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'audioPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'audioPaths',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'audioPaths', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'audioPaths', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'audioPaths', length, true, length, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'audioPaths', 0, true, 0, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'audioPaths', 0, false, 999999, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'audioPaths', 0, true, length, include);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'audioPaths', length, include, 999999, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  audioPathsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'audioPaths',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'compressedDefinitions',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsElementGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'compressedDefinitions',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsElementLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'compressedDefinitions',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'compressedDefinitions',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'compressedDefinitions',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'compressedDefinitions', 0, true, 0, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'compressedDefinitions', 0, false, 999999, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'compressedDefinitions',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'compressedDefinitions',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  compressedDefinitionsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'compressedDefinitions',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  dictionaryIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dictionaryId', value: value),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  dictionaryIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dictionaryId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  dictionaryIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dictionaryId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  dictionaryIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dictionaryId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'entryTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'entryTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'entryTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'entryTagsRaw',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'entryTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'entryTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'entryTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'entryTagsRaw',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'entryTagsRaw', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  entryTagsRawIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'entryTagsRaw', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  hashCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hashCode', value: value),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  hashCodeGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'hashCode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  hashCodeLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'hashCode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  hashCodeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'hashCode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'headingTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'headingTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'headingTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'headingTagsRaw',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'headingTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'headingTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'headingTagsRaw',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'headingTagsRaw',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'headingTagsRaw', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  headingTagsRawIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'headingTagsRaw', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  idGreaterThan(Id? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  idLessThan(Id? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  idBetween(
    Id? lower,
    Id? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'imagePaths'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'imagePaths'),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'imagePaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'imagePaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'imagePaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'imagePaths',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'imagePaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'imagePaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'imagePaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'imagePaths',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'imagePaths', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'imagePaths', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imagePaths', length, true, length, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imagePaths', 0, true, 0, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imagePaths', 0, false, 999999, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imagePaths', 0, true, length, include);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imagePaths', length, include, 999999, true);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  imagePathsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'imagePaths',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  popularityEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'popularity',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  popularityGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'popularity',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  popularityLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'popularity',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  popularityBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'popularity',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'reading',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'reading',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'reading',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'reading',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'reading',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'reading',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'reading',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'reading',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reading', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  readingIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'reading', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'term',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'term',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'term',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'term',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'term',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'term',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'term',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'term',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'term', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'term', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termLengthEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'termLength', value: value),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termLengthGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'termLength',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termLengthLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'termLength',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterFilterCondition>
  termLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'termLength',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension DictionaryEntryQueryObject
    on QueryBuilder<DictionaryEntry, DictionaryEntry, QFilterCondition> {}

extension DictionaryEntryQueryLinks
    on QueryBuilder<DictionaryEntry, DictionaryEntry, QFilterCondition> {}

extension DictionaryEntryQuerySortBy
    on QueryBuilder<DictionaryEntry, DictionaryEntry, QSortBy> {
  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByDictionaryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByEntryTagsRaw() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryTagsRaw', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByEntryTagsRawDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryTagsRaw', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByHeadingTagsRaw() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headingTagsRaw', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByHeadingTagsRawDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headingTagsRaw', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByPopularity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'popularity', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByPopularityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'popularity', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy> sortByReading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByReadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy> sortByTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByTermDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByTermLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'termLength', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  sortByTermLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'termLength', Sort.desc);
    });
  }
}

extension DictionaryEntryQuerySortThenBy
    on QueryBuilder<DictionaryEntry, DictionaryEntry, QSortThenBy> {
  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByDictionaryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByEntryTagsRaw() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryTagsRaw', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByEntryTagsRawDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryTagsRaw', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByHeadingTagsRaw() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headingTagsRaw', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByHeadingTagsRawDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headingTagsRaw', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByPopularity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'popularity', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByPopularityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'popularity', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy> thenByReading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByReadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy> thenByTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByTermDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.desc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByTermLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'termLength', Sort.asc);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QAfterSortBy>
  thenByTermLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'termLength', Sort.desc);
    });
  }
}

extension DictionaryEntryQueryWhereDistinct
    on QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct> {
  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct>
  distinctByAudioPaths() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioPaths');
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct>
  distinctByCompressedDefinitions() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'compressedDefinitions');
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct>
  distinctByDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dictionaryId');
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct>
  distinctByEntryTagsRaw({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entryTagsRaw', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct>
  distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct>
  distinctByHeadingTagsRaw({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'headingTagsRaw',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct>
  distinctByImagePaths() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imagePaths');
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct>
  distinctByPopularity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'popularity');
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct> distinctByReading({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reading', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct> distinctByTerm({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'term', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DictionaryEntry, DictionaryEntry, QDistinct>
  distinctByTermLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'termLength');
    });
  }
}

extension DictionaryEntryQueryProperty
    on QueryBuilder<DictionaryEntry, DictionaryEntry, QQueryProperty> {
  QueryBuilder<DictionaryEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DictionaryEntry, List<String>?, QQueryOperations>
  audioPathsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioPaths');
    });
  }

  QueryBuilder<DictionaryEntry, List<int>, QQueryOperations>
  compressedDefinitionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'compressedDefinitions');
    });
  }

  QueryBuilder<DictionaryEntry, int, QQueryOperations> dictionaryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dictionaryId');
    });
  }

  QueryBuilder<DictionaryEntry, String, QQueryOperations>
  entryTagsRawProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entryTagsRaw');
    });
  }

  QueryBuilder<DictionaryEntry, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<DictionaryEntry, String, QQueryOperations>
  headingTagsRawProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'headingTagsRaw');
    });
  }

  QueryBuilder<DictionaryEntry, List<String>?, QQueryOperations>
  imagePathsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imagePaths');
    });
  }

  QueryBuilder<DictionaryEntry, double, QQueryOperations> popularityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'popularity');
    });
  }

  QueryBuilder<DictionaryEntry, String, QQueryOperations> readingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reading');
    });
  }

  QueryBuilder<DictionaryEntry, String, QQueryOperations> termProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'term');
    });
  }

  QueryBuilder<DictionaryEntry, int, QQueryOperations> termLengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'termLength');
    });
  }
}
