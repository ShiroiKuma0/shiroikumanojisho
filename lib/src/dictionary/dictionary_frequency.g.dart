// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_frequency.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDictionaryFrequencyCollection on Isar {
  IsarCollection<DictionaryFrequency> get dictionaryFrequencys =>
      this.collection();
}

const DictionaryFrequencySchema = CollectionSchema(
  name: r'DictionaryFrequency',
  id: 2045353883102057112,
  properties: {
    r'dictionaryId': PropertySchema(
      id: 0,
      name: r'dictionaryId',
      type: IsarType.long,
    ),
    r'displayValue': PropertySchema(
      id: 1,
      name: r'displayValue',
      type: IsarType.string,
    ),
    r'hashCode': PropertySchema(id: 2, name: r'hashCode', type: IsarType.long),
    r'reading': PropertySchema(id: 3, name: r'reading', type: IsarType.string),
    r'term': PropertySchema(id: 4, name: r'term', type: IsarType.string),
    r'value': PropertySchema(id: 5, name: r'value', type: IsarType.double),
  },

  estimateSize: _dictionaryFrequencyEstimateSize,
  serialize: _dictionaryFrequencySerialize,
  deserialize: _dictionaryFrequencyDeserialize,
  deserializeProp: _dictionaryFrequencyDeserializeProp,
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

  getId: _dictionaryFrequencyGetId,
  getLinks: _dictionaryFrequencyGetLinks,
  attach: _dictionaryFrequencyAttach,
  version: '3.3.2',
);

int _dictionaryFrequencyEstimateSize(
  DictionaryFrequency object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.displayValue.length * 3;
  bytesCount += 3 + object.reading.length * 3;
  bytesCount += 3 + object.term.length * 3;
  return bytesCount;
}

void _dictionaryFrequencySerialize(
  DictionaryFrequency object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.dictionaryId);
  writer.writeString(offsets[1], object.displayValue);
  writer.writeLong(offsets[2], object.hashCode);
  writer.writeString(offsets[3], object.reading);
  writer.writeString(offsets[4], object.term);
  writer.writeDouble(offsets[5], object.value);
}

DictionaryFrequency _dictionaryFrequencyDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DictionaryFrequency(
    dictionaryId: reader.readLong(offsets[0]),
    displayValue: reader.readString(offsets[1]),
    id: id,
    reading: reader.readString(offsets[3]),
    term: reader.readString(offsets[4]),
    value: reader.readDouble(offsets[5]),
  );
  return object;
}

P _dictionaryFrequencyDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _dictionaryFrequencyGetId(DictionaryFrequency object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _dictionaryFrequencyGetLinks(
  DictionaryFrequency object,
) {
  return [];
}

void _dictionaryFrequencyAttach(
  IsarCollection<dynamic> col,
  Id id,
  DictionaryFrequency object,
) {
  object.id = id;
}

extension DictionaryFrequencyQueryWhereSort
    on QueryBuilder<DictionaryFrequency, DictionaryFrequency, QWhere> {
  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhere>
  anyTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'term'),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhere>
  anyDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'dictionaryId'),
      );
    });
  }
}

extension DictionaryFrequencyQueryWhere
    on QueryBuilder<DictionaryFrequency, DictionaryFrequency, QWhereClause> {
  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
  idBetween(
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
  termEqualTo(String term) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'term', value: [term]),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
  termBetween(
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
  termIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'term', value: ['']),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterWhereClause>
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

extension DictionaryFrequencyQueryFilter
    on
        QueryBuilder<
          DictionaryFrequency,
          DictionaryFrequency,
          QFilterCondition
        > {
  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  dictionaryIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dictionaryId', value: value),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'displayValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'displayValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'displayValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'displayValue',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'displayValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'displayValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'displayValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'displayValue',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'displayValue', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  displayValueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'displayValue', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  hashCodeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hashCode', value: value),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  readingIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reading', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  readingIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'reading', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
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

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  termIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'term', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  termIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'term', value: ''),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  valueEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'value',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  valueGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'value',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  valueLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'value',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterFilterCondition>
  valueBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'value',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }
}

extension DictionaryFrequencyQueryObject
    on
        QueryBuilder<
          DictionaryFrequency,
          DictionaryFrequency,
          QFilterCondition
        > {}

extension DictionaryFrequencyQueryLinks
    on
        QueryBuilder<
          DictionaryFrequency,
          DictionaryFrequency,
          QFilterCondition
        > {}

extension DictionaryFrequencyQuerySortBy
    on QueryBuilder<DictionaryFrequency, DictionaryFrequency, QSortBy> {
  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByDictionaryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByDisplayValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayValue', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByDisplayValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayValue', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByReading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByReadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByTermDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  sortByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension DictionaryFrequencyQuerySortThenBy
    on QueryBuilder<DictionaryFrequency, DictionaryFrequency, QSortThenBy> {
  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByDictionaryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictionaryId', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByDisplayValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayValue', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByDisplayValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayValue', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByHashCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hashCode', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByReading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByReadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reading', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByTerm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByTermDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'term', Sort.desc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QAfterSortBy>
  thenByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension DictionaryFrequencyQueryWhereDistinct
    on QueryBuilder<DictionaryFrequency, DictionaryFrequency, QDistinct> {
  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QDistinct>
  distinctByDictionaryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dictionaryId');
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QDistinct>
  distinctByDisplayValue({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayValue', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QDistinct>
  distinctByHashCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hashCode');
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QDistinct>
  distinctByReading({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reading', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QDistinct>
  distinctByTerm({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'term', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DictionaryFrequency, DictionaryFrequency, QDistinct>
  distinctByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'value');
    });
  }
}

extension DictionaryFrequencyQueryProperty
    on QueryBuilder<DictionaryFrequency, DictionaryFrequency, QQueryProperty> {
  QueryBuilder<DictionaryFrequency, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DictionaryFrequency, int, QQueryOperations>
  dictionaryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dictionaryId');
    });
  }

  QueryBuilder<DictionaryFrequency, String, QQueryOperations>
  displayValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayValue');
    });
  }

  QueryBuilder<DictionaryFrequency, int, QQueryOperations> hashCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hashCode');
    });
  }

  QueryBuilder<DictionaryFrequency, String, QQueryOperations>
  readingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reading');
    });
  }

  QueryBuilder<DictionaryFrequency, String, QQueryOperations> termProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'term');
    });
  }

  QueryBuilder<DictionaryFrequency, double, QQueryOperations> valueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'value');
    });
  }
}
