// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_pitch.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDictionaryPitchCollection on Isar {
  IsarCollection<DictionaryPitch> get dictionaryPitchs => this.collection();
}

const DictionaryPitchSchema = CollectionSchema(
  name: r'DictionaryPitch',
  id: 7201735020230863881,
  properties: {
    r'dictionaryId': PropertySchema(
      id: 0,
      name: r'dictionaryId',
      type: IsarType.long,
    ),
    r'downstep': PropertySchema(id: 1, name: r'downstep', type: IsarType.long),
    r'hashCode': PropertySchema(id: 2, name: r'hashCode', type: IsarType.long),
    r'reading': PropertySchema(id: 3, name: r'reading', type: IsarType.string),
    r'term': PropertySchema(id: 4, name: r'term', type: IsarType.string),
  },

  estimateSize: _dictionaryPitchEstimateSize,
  serialize: _dictionaryPitchSerialize,
  deserialize: _dictionaryPitchDeserialize,
  deserializeProp: _dictionaryPitchDeserializeProp,
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
  },
  links: {},
  embeddedSchemas: {},

  getId: _dictionaryPitchGetId,
  getLinks: _dictionaryPitchGetLinks,
  attach: _dictionaryPitchAttach,
  version: '3.3.2',
);

int _dictionaryPitchEstimateSize(
  DictionaryPitch object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.reading.length * 3;
  bytesCount += 3 + object.term.length * 3;
  return bytesCount;
}

void _dictionaryPitchSerialize(
  DictionaryPitch object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.dictionaryId);
  writer.writeLong(offsets[1], object.downstep);
  writer.writeLong(offsets[2], object.hashCode);
  writer.writeString(offsets[3], object.reading);
  writer.writeString(offsets[4], object.term);
}

DictionaryPitch _dictionaryPitchDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DictionaryPitch(
    dictionaryId: reader.readLong(offsets[0]),
    downstep: reader.readLong(offsets[1]),
    id: id,
    reading: reader.readString(offsets[3]),
    term: reader.readString(offsets[4]),
  );
  return object;
}

P _dictionaryPitchDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _dictionaryPitchGetId(DictionaryPitch object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _dictionaryPitchGetLinks(DictionaryPitch object) {
  return [];
}

void _dictionaryPitchAttach(
  IsarCollection<dynamic> col,
  Id id,
  DictionaryPitch object,
) {
  object.id = id;
}

extension DictionaryPitchQueryWhereSort
    on QueryBuilder<DictionaryPitch, DictionaryPitch, QWhere> {
  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhere> anyTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'term'),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhere>
  anyDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'dictionaryId'),
      );
    });
  }
}

extension DictionaryPitchQueryWhere
    on QueryBuilder<DictionaryPitch, DictionaryPitch, QWhereClause> {
  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause> idBetween(
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause> termEqualTo(
    String term,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'term', value: [term]),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause> termBetween(
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
  termIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'term', value: ['']),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterWhereClause>
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
}

extension DictionaryPitchQueryFilter
    on QueryBuilder<DictionaryPitch, DictionaryPitch, QFilterCondition> {
  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  dictionaryIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dictionaryId', value: value),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  downstepEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'downstep', value: value),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  downstepGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'downstep',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  downstepLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'downstep',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  downstepBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'downstep',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  hashCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hashCode', value: value),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  readingIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reading', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  readingIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'reading', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
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

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  termIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'term', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterFilterCondition>
  termIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'term', value: ''),
      );
    });
  }
}

extension DictionaryPitchQueryObject
    on QueryBuilder<DictionaryPitch, DictionaryPitch, QFilterCondition> {}

extension DictionaryPitchQueryLinks
    on QueryBuilder<DictionaryPitch, DictionaryPitch, QFilterCondition> {}

extension DictionaryPitchQuerySortBy
    on QueryBuilder<DictionaryPitch, DictionaryPitch, QSortBy> {
  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  sortByDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  sortByDictionaryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.desc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  sortByDownstep() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downstep', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  sortByDownstepDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downstep', Sort.desc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy> sortByReading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  sortByReadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.desc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy> sortByTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  sortByTermDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.desc);
    });
  }
}

extension DictionaryPitchQuerySortThenBy
    on QueryBuilder<DictionaryPitch, DictionaryPitch, QSortThenBy> {
  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  thenByDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  thenByDictionaryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.desc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  thenByDownstep() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downstep', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  thenByDownstepDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downstep', Sort.desc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy> thenByReading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  thenByReadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.desc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy> thenByTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.asc);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QAfterSortBy>
  thenByTermDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.desc);
    });
  }
}

extension DictionaryPitchQueryWhereDistinct
    on QueryBuilder<DictionaryPitch, DictionaryPitch, QDistinct> {
  QueryBuilder<DictionaryPitch, DictionaryPitch, QDistinct>
  distinctByDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dictionaryId');
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QDistinct>
  distinctByDownstep() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'downstep');
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QDistinct>
  distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QDistinct> distinctByReading({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reading', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DictionaryPitch, DictionaryPitch, QDistinct> distinctByTerm({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'term', caseSensitive: caseSensitive);
    });
  }
}

extension DictionaryPitchQueryProperty
    on QueryBuilder<DictionaryPitch, DictionaryPitch, QQueryProperty> {
  QueryBuilder<DictionaryPitch, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DictionaryPitch, int, QQueryOperations> dictionaryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dictionaryId');
    });
  }

  QueryBuilder<DictionaryPitch, int, QQueryOperations> downstepProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'downstep');
    });
  }

  QueryBuilder<DictionaryPitch, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<DictionaryPitch, String, QQueryOperations> readingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reading');
    });
  }

  QueryBuilder<DictionaryPitch, String, QQueryOperations> termProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'term');
    });
  }
}
