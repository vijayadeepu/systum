// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $GoalsTable extends Goals with TableInfo<$GoalsTable, GoalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<GoalDate?, int> targetDate =
      GeneratedColumn<int>(
        'target_date',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<GoalDate?>($GoalsTable.$convertertargetDaten);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    targetDate,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      targetDate: $GoalsTable.$convertertargetDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}target_date'],
        ),
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }

  static TypeConverter<GoalDate, int> $convertertargetDate =
      const GoalDateConverter();
  static TypeConverter<GoalDate?, int?> $convertertargetDaten =
      NullAwareTypeConverter.wrap($convertertargetDate);
}

class GoalRow extends DataClass implements Insertable<GoalRow> {
  final String id;
  final String title;
  final String? description;
  final GoalDate? targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  const GoalRow({
    required this.id,
    required this.title,
    this.description,
    this.targetDate,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<int>(
        $GoalsTable.$convertertargetDaten.toSql(targetDate),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GoalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      targetDate: serializer.fromJson<GoalDate?>(json['targetDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'targetDate': serializer.toJson<GoalDate?>(targetDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GoalRow copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<GoalDate?> targetDate = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GoalRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GoalRow copyWithCompanion(GoalsCompanion data) {
    return GoalRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('targetDate: $targetDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, description, targetDate, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.targetDate == this.targetDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GoalsCompanion extends UpdateCompanion<GoalRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<GoalDate?> targetDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    this.targetDate = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GoalRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? targetDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (targetDate != null) 'target_date': targetDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<GoalDate?>? targetDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<int>(
        $GoalsTable.$convertertargetDaten.toSql(targetDate.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('targetDate: $targetDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueTimeMeta = const VerificationMeta(
    'dueTime',
  );
  @override
  late final GeneratedColumn<int> dueTime = GeneratedColumn<int>(
    'due_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueTimezoneMeta = const VerificationMeta(
    'dueTimezone',
  );
  @override
  late final GeneratedColumn<String> dueTimezone = GeneratedColumn<String>(
    'due_timezone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 80),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _parentTaskIdMeta = const VerificationMeta(
    'parentTaskId',
  );
  @override
  late final GeneratedColumn<String> parentTaskId = GeneratedColumn<String>(
    'parent_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    completed,
    createdAt,
    updatedAt,
    dueDate,
    dueTime,
    dueTimezone,
    priority,
    category,
    goalId,
    parentTaskId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('due_time')) {
      context.handle(
        _dueTimeMeta,
        dueTime.isAcceptableOrUnknown(data['due_time']!, _dueTimeMeta),
      );
    }
    if (data.containsKey('due_timezone')) {
      context.handle(
        _dueTimezoneMeta,
        dueTimezone.isAcceptableOrUnknown(
          data['due_timezone']!,
          _dueTimezoneMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    }
    if (data.containsKey('parent_task_id')) {
      context.handle(
        _parentTaskIdMeta,
        parentTaskId.isAcceptableOrUnknown(
          data['parent_task_id']!,
          _parentTaskIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      dueTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_time'],
      ),
      dueTimezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_timezone'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      ),
      parentTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_task_id'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final String id;
  final String title;
  final String? description;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;

  /// Seconds since midnight (0-86399) in [dueTimezone], or null when no due
  /// time is set.
  final int? dueTime;

  /// IANA timezone identifier (e.g. "America/New_York") used to interpret
  /// [dueTime] against [dueDate]. Null means the local device timezone.
  final String? dueTimezone;
  final int priority;
  final String? category;
  final String? goalId;
  final String? parentTaskId;
  const TaskRow({
    required this.id,
    required this.title,
    this.description,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.dueTime,
    this.dueTimezone,
    required this.priority,
    this.category,
    this.goalId,
    this.parentTaskId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['completed'] = Variable<bool>(completed);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || dueTime != null) {
      map['due_time'] = Variable<int>(dueTime);
    }
    if (!nullToAbsent || dueTimezone != null) {
      map['due_timezone'] = Variable<String>(dueTimezone);
    }
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<String>(parentTaskId);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      completed: Value(completed),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      dueTime: dueTime == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTime),
      dueTimezone: dueTimezone == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTimezone),
      priority: Value(priority),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      goalId: goalId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalId),
      parentTaskId: parentTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTaskId),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      completed: serializer.fromJson<bool>(json['completed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      dueTime: serializer.fromJson<int?>(json['dueTime']),
      dueTimezone: serializer.fromJson<String?>(json['dueTimezone']),
      priority: serializer.fromJson<int>(json['priority']),
      category: serializer.fromJson<String?>(json['category']),
      goalId: serializer.fromJson<String?>(json['goalId']),
      parentTaskId: serializer.fromJson<String?>(json['parentTaskId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'completed': serializer.toJson<bool>(completed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'dueTime': serializer.toJson<int?>(dueTime),
      'dueTimezone': serializer.toJson<String?>(dueTimezone),
      'priority': serializer.toJson<int>(priority),
      'category': serializer.toJson<String?>(category),
      'goalId': serializer.toJson<String?>(goalId),
      'parentTaskId': serializer.toJson<String?>(parentTaskId),
    };
  }

  TaskRow copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> dueDate = const Value.absent(),
    Value<int?> dueTime = const Value.absent(),
    Value<String?> dueTimezone = const Value.absent(),
    int? priority,
    Value<String?> category = const Value.absent(),
    Value<String?> goalId = const Value.absent(),
    Value<String?> parentTaskId = const Value.absent(),
  }) => TaskRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    completed: completed ?? this.completed,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    dueTime: dueTime.present ? dueTime.value : this.dueTime,
    dueTimezone: dueTimezone.present ? dueTimezone.value : this.dueTimezone,
    priority: priority ?? this.priority,
    category: category.present ? category.value : this.category,
    goalId: goalId.present ? goalId.value : this.goalId,
    parentTaskId: parentTaskId.present ? parentTaskId.value : this.parentTaskId,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      completed: data.completed.present ? data.completed.value : this.completed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      dueTime: data.dueTime.present ? data.dueTime.value : this.dueTime,
      dueTimezone: data.dueTimezone.present
          ? data.dueTimezone.value
          : this.dueTimezone,
      priority: data.priority.present ? data.priority.value : this.priority,
      category: data.category.present ? data.category.value : this.category,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      parentTaskId: data.parentTaskId.present
          ? data.parentTaskId.value
          : this.parentTaskId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('completed: $completed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueTime: $dueTime, ')
          ..write('dueTimezone: $dueTimezone, ')
          ..write('priority: $priority, ')
          ..write('category: $category, ')
          ..write('goalId: $goalId, ')
          ..write('parentTaskId: $parentTaskId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    completed,
    createdAt,
    updatedAt,
    dueDate,
    dueTime,
    dueTimezone,
    priority,
    category,
    goalId,
    parentTaskId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.completed == this.completed &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.dueDate == this.dueDate &&
          other.dueTime == this.dueTime &&
          other.dueTimezone == this.dueTimezone &&
          other.priority == this.priority &&
          other.category == this.category &&
          other.goalId == this.goalId &&
          other.parentTaskId == this.parentTaskId);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<bool> completed;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> dueDate;
  final Value<int?> dueTime;
  final Value<String?> dueTimezone;
  final Value<int> priority;
  final Value<String?> category;
  final Value<String?> goalId;
  final Value<String?> parentTaskId;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.completed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.dueTimezone = const Value.absent(),
    this.priority = const Value.absent(),
    this.category = const Value.absent(),
    this.goalId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    this.completed = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.dueDate = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.dueTimezone = const Value.absent(),
    this.priority = const Value.absent(),
    this.category = const Value.absent(),
    this.goalId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? completed,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? dueDate,
    Expression<int>? dueTime,
    Expression<String>? dueTimezone,
    Expression<int>? priority,
    Expression<String>? category,
    Expression<String>? goalId,
    Expression<String>? parentTaskId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (completed != null) 'completed': completed,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dueDate != null) 'due_date': dueDate,
      if (dueTime != null) 'due_time': dueTime,
      if (dueTimezone != null) 'due_timezone': dueTimezone,
      if (priority != null) 'priority': priority,
      if (category != null) 'category': category,
      if (goalId != null) 'goal_id': goalId,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<bool>? completed,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? dueDate,
    Value<int?>? dueTime,
    Value<String?>? dueTimezone,
    Value<int>? priority,
    Value<String?>? category,
    Value<String?>? goalId,
    Value<String?>? parentTaskId,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      dueTimezone: dueTimezone ?? this.dueTimezone,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      goalId: goalId ?? this.goalId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (dueTime.present) {
      map['due_time'] = Variable<int>(dueTime.value);
    }
    if (dueTimezone.present) {
      map['due_timezone'] = Variable<String>(dueTimezone.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<String>(parentTaskId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('completed: $completed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueTime: $dueTime, ')
          ..write('dueTimezone: $dueTimezone, ')
          ..write('priority: $priority, ')
          ..write('category: $category, ')
          ..write('goalId: $goalId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusSessionsTable extends FocusSessions
    with TableInfo<$FocusSessionsTable, FocusSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _taskIdAtStartMeta = const VerificationMeta(
    'taskIdAtStart',
  );
  @override
  late final GeneratedColumn<String> taskIdAtStart = GeneratedColumn<String>(
    'task_id_at_start',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskTitleAtStartMeta = const VerificationMeta(
    'taskTitleAtStart',
  );
  @override
  late final GeneratedColumn<String> taskTitleAtStart = GeneratedColumn<String>(
    'task_title_at_start',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FocusSessionMode, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FocusSessionMode>($FocusSessionsTable.$convertermode);
  @override
  late final GeneratedColumnWithTypeConverter<FocusSessionStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<FocusSessionStatus>($FocusSessionsTable.$converterstatus);
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMsMeta = const VerificationMeta(
    'endedAtMs',
  );
  @override
  late final GeneratedColumn<int> endedAtMs = GeneratedColumn<int>(
    'ended_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedDurationMsMeta = const VerificationMeta(
    'plannedDurationMs',
  );
  @override
  late final GeneratedColumn<int> plannedDurationMs = GeneratedColumn<int>(
    'planned_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualDurationMsMeta = const VerificationMeta(
    'actualDurationMs',
  );
  @override
  late final GeneratedColumn<int> actualDurationMs = GeneratedColumn<int>(
    'actual_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cycleIdMeta = const VerificationMeta(
    'cycleId',
  );
  @override
  late final GeneratedColumn<String> cycleId = GeneratedColumn<String>(
    'cycle_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cycleRoundMeta = const VerificationMeta(
    'cycleRound',
  );
  @override
  late final GeneratedColumn<int> cycleRound = GeneratedColumn<int>(
    'cycle_round',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    taskIdAtStart,
    taskTitleAtStart,
    mode,
    status,
    startedAtMs,
    endedAtMs,
    plannedDurationMs,
    actualDurationMs,
    cycleId,
    cycleRound,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FocusSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('task_id_at_start')) {
      context.handle(
        _taskIdAtStartMeta,
        taskIdAtStart.isAcceptableOrUnknown(
          data['task_id_at_start']!,
          _taskIdAtStartMeta,
        ),
      );
    }
    if (data.containsKey('task_title_at_start')) {
      context.handle(
        _taskTitleAtStartMeta,
        taskTitleAtStart.isAcceptableOrUnknown(
          data['task_title_at_start']!,
          _taskTitleAtStartMeta,
        ),
      );
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMsMeta);
    }
    if (data.containsKey('ended_at_ms')) {
      context.handle(
        _endedAtMsMeta,
        endedAtMs.isAcceptableOrUnknown(data['ended_at_ms']!, _endedAtMsMeta),
      );
    }
    if (data.containsKey('planned_duration_ms')) {
      context.handle(
        _plannedDurationMsMeta,
        plannedDurationMs.isAcceptableOrUnknown(
          data['planned_duration_ms']!,
          _plannedDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('actual_duration_ms')) {
      context.handle(
        _actualDurationMsMeta,
        actualDurationMs.isAcceptableOrUnknown(
          data['actual_duration_ms']!,
          _actualDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('cycle_id')) {
      context.handle(
        _cycleIdMeta,
        cycleId.isAcceptableOrUnknown(data['cycle_id']!, _cycleIdMeta),
      );
    }
    if (data.containsKey('cycle_round')) {
      context.handle(
        _cycleRoundMeta,
        cycleRound.isAcceptableOrUnknown(data['cycle_round']!, _cycleRoundMeta),
      );
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      taskIdAtStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id_at_start'],
      ),
      taskTitleAtStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_title_at_start'],
      ),
      mode: $FocusSessionsTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        )!,
      ),
      status: $FocusSessionsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      endedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_ms'],
      ),
      plannedDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_duration_ms'],
      ),
      actualDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_duration_ms'],
      ),
      cycleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_id'],
      ),
      cycleRound: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycle_round'],
      ),
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $FocusSessionsTable createAlias(String alias) {
    return $FocusSessionsTable(attachedDatabase, alias);
  }

  static TypeConverter<FocusSessionMode, String> $convertermode =
      const FocusSessionModeConverter();
  static TypeConverter<FocusSessionStatus, String> $converterstatus =
      const FocusSessionStatusConverter();
}

class FocusSessionRow extends DataClass implements Insertable<FocusSessionRow> {
  final String id;
  final String? taskId;
  final String? taskIdAtStart;
  final String? taskTitleAtStart;
  final FocusSessionMode mode;
  final FocusSessionStatus status;
  final int startedAtMs;
  final int? endedAtMs;
  final int? plannedDurationMs;
  final int? actualDurationMs;
  final String? cycleId;
  final int? cycleRound;
  final int updatedAtMs;
  const FocusSessionRow({
    required this.id,
    this.taskId,
    this.taskIdAtStart,
    this.taskTitleAtStart,
    required this.mode,
    required this.status,
    required this.startedAtMs,
    this.endedAtMs,
    this.plannedDurationMs,
    this.actualDurationMs,
    this.cycleId,
    this.cycleRound,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || taskIdAtStart != null) {
      map['task_id_at_start'] = Variable<String>(taskIdAtStart);
    }
    if (!nullToAbsent || taskTitleAtStart != null) {
      map['task_title_at_start'] = Variable<String>(taskTitleAtStart);
    }
    {
      map['mode'] = Variable<String>(
        $FocusSessionsTable.$convertermode.toSql(mode),
      );
    }
    {
      map['status'] = Variable<String>(
        $FocusSessionsTable.$converterstatus.toSql(status),
      );
    }
    map['started_at_ms'] = Variable<int>(startedAtMs);
    if (!nullToAbsent || endedAtMs != null) {
      map['ended_at_ms'] = Variable<int>(endedAtMs);
    }
    if (!nullToAbsent || plannedDurationMs != null) {
      map['planned_duration_ms'] = Variable<int>(plannedDurationMs);
    }
    if (!nullToAbsent || actualDurationMs != null) {
      map['actual_duration_ms'] = Variable<int>(actualDurationMs);
    }
    if (!nullToAbsent || cycleId != null) {
      map['cycle_id'] = Variable<String>(cycleId);
    }
    if (!nullToAbsent || cycleRound != null) {
      map['cycle_round'] = Variable<int>(cycleRound);
    }
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  FocusSessionsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionsCompanion(
      id: Value(id),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      taskIdAtStart: taskIdAtStart == null && nullToAbsent
          ? const Value.absent()
          : Value(taskIdAtStart),
      taskTitleAtStart: taskTitleAtStart == null && nullToAbsent
          ? const Value.absent()
          : Value(taskTitleAtStart),
      mode: Value(mode),
      status: Value(status),
      startedAtMs: Value(startedAtMs),
      endedAtMs: endedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtMs),
      plannedDurationMs: plannedDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedDurationMs),
      actualDurationMs: actualDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(actualDurationMs),
      cycleId: cycleId == null && nullToAbsent
          ? const Value.absent()
          : Value(cycleId),
      cycleRound: cycleRound == null && nullToAbsent
          ? const Value.absent()
          : Value(cycleRound),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory FocusSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSessionRow(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      taskIdAtStart: serializer.fromJson<String?>(json['taskIdAtStart']),
      taskTitleAtStart: serializer.fromJson<String?>(json['taskTitleAtStart']),
      mode: serializer.fromJson<FocusSessionMode>(json['mode']),
      status: serializer.fromJson<FocusSessionStatus>(json['status']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      endedAtMs: serializer.fromJson<int?>(json['endedAtMs']),
      plannedDurationMs: serializer.fromJson<int?>(json['plannedDurationMs']),
      actualDurationMs: serializer.fromJson<int?>(json['actualDurationMs']),
      cycleId: serializer.fromJson<String?>(json['cycleId']),
      cycleRound: serializer.fromJson<int?>(json['cycleRound']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String?>(taskId),
      'taskIdAtStart': serializer.toJson<String?>(taskIdAtStart),
      'taskTitleAtStart': serializer.toJson<String?>(taskTitleAtStart),
      'mode': serializer.toJson<FocusSessionMode>(mode),
      'status': serializer.toJson<FocusSessionStatus>(status),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'endedAtMs': serializer.toJson<int?>(endedAtMs),
      'plannedDurationMs': serializer.toJson<int?>(plannedDurationMs),
      'actualDurationMs': serializer.toJson<int?>(actualDurationMs),
      'cycleId': serializer.toJson<String?>(cycleId),
      'cycleRound': serializer.toJson<int?>(cycleRound),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  FocusSessionRow copyWith({
    String? id,
    Value<String?> taskId = const Value.absent(),
    Value<String?> taskIdAtStart = const Value.absent(),
    Value<String?> taskTitleAtStart = const Value.absent(),
    FocusSessionMode? mode,
    FocusSessionStatus? status,
    int? startedAtMs,
    Value<int?> endedAtMs = const Value.absent(),
    Value<int?> plannedDurationMs = const Value.absent(),
    Value<int?> actualDurationMs = const Value.absent(),
    Value<String?> cycleId = const Value.absent(),
    Value<int?> cycleRound = const Value.absent(),
    int? updatedAtMs,
  }) => FocusSessionRow(
    id: id ?? this.id,
    taskId: taskId.present ? taskId.value : this.taskId,
    taskIdAtStart: taskIdAtStart.present
        ? taskIdAtStart.value
        : this.taskIdAtStart,
    taskTitleAtStart: taskTitleAtStart.present
        ? taskTitleAtStart.value
        : this.taskTitleAtStart,
    mode: mode ?? this.mode,
    status: status ?? this.status,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    endedAtMs: endedAtMs.present ? endedAtMs.value : this.endedAtMs,
    plannedDurationMs: plannedDurationMs.present
        ? plannedDurationMs.value
        : this.plannedDurationMs,
    actualDurationMs: actualDurationMs.present
        ? actualDurationMs.value
        : this.actualDurationMs,
    cycleId: cycleId.present ? cycleId.value : this.cycleId,
    cycleRound: cycleRound.present ? cycleRound.value : this.cycleRound,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  FocusSessionRow copyWithCompanion(FocusSessionsCompanion data) {
    return FocusSessionRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      taskIdAtStart: data.taskIdAtStart.present
          ? data.taskIdAtStart.value
          : this.taskIdAtStart,
      taskTitleAtStart: data.taskTitleAtStart.present
          ? data.taskTitleAtStart.value
          : this.taskTitleAtStart,
      mode: data.mode.present ? data.mode.value : this.mode,
      status: data.status.present ? data.status.value : this.status,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      endedAtMs: data.endedAtMs.present ? data.endedAtMs.value : this.endedAtMs,
      plannedDurationMs: data.plannedDurationMs.present
          ? data.plannedDurationMs.value
          : this.plannedDurationMs,
      actualDurationMs: data.actualDurationMs.present
          ? data.actualDurationMs.value
          : this.actualDurationMs,
      cycleId: data.cycleId.present ? data.cycleId.value : this.cycleId,
      cycleRound: data.cycleRound.present
          ? data.cycleRound.value
          : this.cycleRound,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('taskIdAtStart: $taskIdAtStart, ')
          ..write('taskTitleAtStart: $taskTitleAtStart, ')
          ..write('mode: $mode, ')
          ..write('status: $status, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('plannedDurationMs: $plannedDurationMs, ')
          ..write('actualDurationMs: $actualDurationMs, ')
          ..write('cycleId: $cycleId, ')
          ..write('cycleRound: $cycleRound, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    taskIdAtStart,
    taskTitleAtStart,
    mode,
    status,
    startedAtMs,
    endedAtMs,
    plannedDurationMs,
    actualDurationMs,
    cycleId,
    cycleRound,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSessionRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.taskIdAtStart == this.taskIdAtStart &&
          other.taskTitleAtStart == this.taskTitleAtStart &&
          other.mode == this.mode &&
          other.status == this.status &&
          other.startedAtMs == this.startedAtMs &&
          other.endedAtMs == this.endedAtMs &&
          other.plannedDurationMs == this.plannedDurationMs &&
          other.actualDurationMs == this.actualDurationMs &&
          other.cycleId == this.cycleId &&
          other.cycleRound == this.cycleRound &&
          other.updatedAtMs == this.updatedAtMs);
}

class FocusSessionsCompanion extends UpdateCompanion<FocusSessionRow> {
  final Value<String> id;
  final Value<String?> taskId;
  final Value<String?> taskIdAtStart;
  final Value<String?> taskTitleAtStart;
  final Value<FocusSessionMode> mode;
  final Value<FocusSessionStatus> status;
  final Value<int> startedAtMs;
  final Value<int?> endedAtMs;
  final Value<int?> plannedDurationMs;
  final Value<int?> actualDurationMs;
  final Value<String?> cycleId;
  final Value<int?> cycleRound;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const FocusSessionsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.taskIdAtStart = const Value.absent(),
    this.taskTitleAtStart = const Value.absent(),
    this.mode = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.endedAtMs = const Value.absent(),
    this.plannedDurationMs = const Value.absent(),
    this.actualDurationMs = const Value.absent(),
    this.cycleId = const Value.absent(),
    this.cycleRound = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSessionsCompanion.insert({
    required String id,
    this.taskId = const Value.absent(),
    this.taskIdAtStart = const Value.absent(),
    this.taskTitleAtStart = const Value.absent(),
    required FocusSessionMode mode,
    required FocusSessionStatus status,
    required int startedAtMs,
    this.endedAtMs = const Value.absent(),
    this.plannedDurationMs = const Value.absent(),
    this.actualDurationMs = const Value.absent(),
    this.cycleId = const Value.absent(),
    this.cycleRound = const Value.absent(),
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mode = Value(mode),
       status = Value(status),
       startedAtMs = Value(startedAtMs),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<FocusSessionRow> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? taskIdAtStart,
    Expression<String>? taskTitleAtStart,
    Expression<String>? mode,
    Expression<String>? status,
    Expression<int>? startedAtMs,
    Expression<int>? endedAtMs,
    Expression<int>? plannedDurationMs,
    Expression<int>? actualDurationMs,
    Expression<String>? cycleId,
    Expression<int>? cycleRound,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (taskIdAtStart != null) 'task_id_at_start': taskIdAtStart,
      if (taskTitleAtStart != null) 'task_title_at_start': taskTitleAtStart,
      if (mode != null) 'mode': mode,
      if (status != null) 'status': status,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (endedAtMs != null) 'ended_at_ms': endedAtMs,
      if (plannedDurationMs != null) 'planned_duration_ms': plannedDurationMs,
      if (actualDurationMs != null) 'actual_duration_ms': actualDurationMs,
      if (cycleId != null) 'cycle_id': cycleId,
      if (cycleRound != null) 'cycle_round': cycleRound,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? taskId,
    Value<String?>? taskIdAtStart,
    Value<String?>? taskTitleAtStart,
    Value<FocusSessionMode>? mode,
    Value<FocusSessionStatus>? status,
    Value<int>? startedAtMs,
    Value<int?>? endedAtMs,
    Value<int?>? plannedDurationMs,
    Value<int?>? actualDurationMs,
    Value<String?>? cycleId,
    Value<int?>? cycleRound,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return FocusSessionsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      taskIdAtStart: taskIdAtStart ?? this.taskIdAtStart,
      taskTitleAtStart: taskTitleAtStart ?? this.taskTitleAtStart,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
      plannedDurationMs: plannedDurationMs ?? this.plannedDurationMs,
      actualDurationMs: actualDurationMs ?? this.actualDurationMs,
      cycleId: cycleId ?? this.cycleId,
      cycleRound: cycleRound ?? this.cycleRound,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (taskIdAtStart.present) {
      map['task_id_at_start'] = Variable<String>(taskIdAtStart.value);
    }
    if (taskTitleAtStart.present) {
      map['task_title_at_start'] = Variable<String>(taskTitleAtStart.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $FocusSessionsTable.$convertermode.toSql(mode.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $FocusSessionsTable.$converterstatus.toSql(status.value),
      );
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (endedAtMs.present) {
      map['ended_at_ms'] = Variable<int>(endedAtMs.value);
    }
    if (plannedDurationMs.present) {
      map['planned_duration_ms'] = Variable<int>(plannedDurationMs.value);
    }
    if (actualDurationMs.present) {
      map['actual_duration_ms'] = Variable<int>(actualDurationMs.value);
    }
    if (cycleId.present) {
      map['cycle_id'] = Variable<String>(cycleId.value);
    }
    if (cycleRound.present) {
      map['cycle_round'] = Variable<int>(cycleRound.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('taskIdAtStart: $taskIdAtStart, ')
          ..write('taskTitleAtStart: $taskTitleAtStart, ')
          ..write('mode: $mode, ')
          ..write('status: $status, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('plannedDurationMs: $plannedDurationMs, ')
          ..write('actualDurationMs: $actualDurationMs, ')
          ..write('cycleId: $cycleId, ')
          ..write('cycleRound: $cycleRound, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusSessionIntervalsTable extends FocusSessionIntervals
    with TableInfo<$FocusSessionIntervalsTable, FocusSessionIntervalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionIntervalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES focus_sessions (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMsMeta = const VerificationMeta(
    'endedAtMs',
  );
  @override
  late final GeneratedColumn<int> endedAtMs = GeneratedColumn<int>(
    'ended_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, startedAtMs, endedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_session_intervals';
  @override
  VerificationContext validateIntegrity(
    Insertable<FocusSessionIntervalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMsMeta);
    }
    if (data.containsKey('ended_at_ms')) {
      context.handle(
        _endedAtMsMeta,
        endedAtMs.isAcceptableOrUnknown(data['ended_at_ms']!, _endedAtMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSessionIntervalRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSessionIntervalRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      endedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_ms'],
      ),
    );
  }

  @override
  $FocusSessionIntervalsTable createAlias(String alias) {
    return $FocusSessionIntervalsTable(attachedDatabase, alias);
  }
}

class FocusSessionIntervalRow extends DataClass
    implements Insertable<FocusSessionIntervalRow> {
  final String id;
  final String sessionId;
  final int startedAtMs;
  final int? endedAtMs;
  const FocusSessionIntervalRow({
    required this.id,
    required this.sessionId,
    required this.startedAtMs,
    this.endedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['started_at_ms'] = Variable<int>(startedAtMs);
    if (!nullToAbsent || endedAtMs != null) {
      map['ended_at_ms'] = Variable<int>(endedAtMs);
    }
    return map;
  }

  FocusSessionIntervalsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionIntervalsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      startedAtMs: Value(startedAtMs),
      endedAtMs: endedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtMs),
    );
  }

  factory FocusSessionIntervalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSessionIntervalRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      endedAtMs: serializer.fromJson<int?>(json['endedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'endedAtMs': serializer.toJson<int?>(endedAtMs),
    };
  }

  FocusSessionIntervalRow copyWith({
    String? id,
    String? sessionId,
    int? startedAtMs,
    Value<int?> endedAtMs = const Value.absent(),
  }) => FocusSessionIntervalRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    endedAtMs: endedAtMs.present ? endedAtMs.value : this.endedAtMs,
  );
  FocusSessionIntervalRow copyWithCompanion(
    FocusSessionIntervalsCompanion data,
  ) {
    return FocusSessionIntervalRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      endedAtMs: data.endedAtMs.present ? data.endedAtMs.value : this.endedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionIntervalRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, startedAtMs, endedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSessionIntervalRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.startedAtMs == this.startedAtMs &&
          other.endedAtMs == this.endedAtMs);
}

class FocusSessionIntervalsCompanion
    extends UpdateCompanion<FocusSessionIntervalRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> startedAtMs;
  final Value<int?> endedAtMs;
  final Value<int> rowid;
  const FocusSessionIntervalsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.endedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSessionIntervalsCompanion.insert({
    required String id,
    required String sessionId,
    required int startedAtMs,
    this.endedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       startedAtMs = Value(startedAtMs);
  static Insertable<FocusSessionIntervalRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? startedAtMs,
    Expression<int>? endedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (endedAtMs != null) 'ended_at_ms': endedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSessionIntervalsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? startedAtMs,
    Value<int?>? endedAtMs,
    Value<int>? rowid,
  }) {
    return FocusSessionIntervalsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (endedAtMs.present) {
      map['ended_at_ms'] = Variable<int>(endedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionIntervalsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskRecurrenceRulesTable extends TaskRecurrenceRules
    with TableInfo<$TaskRecurrenceRulesTable, TaskRecurrenceRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskRecurrenceRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentTaskIdMeta = const VerificationMeta(
    'parentTaskId',
  );
  @override
  late final GeneratedColumn<String> parentTaskId = GeneratedColumn<String>(
    'parent_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _recurrenceTypeMeta = const VerificationMeta(
    'recurrenceType',
  );
  @override
  late final GeneratedColumn<String> recurrenceType = GeneratedColumn<String>(
    'recurrence_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
    'interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _weekdaysMeta = const VerificationMeta(
    'weekdays',
  );
  @override
  late final GeneratedColumn<int> weekdays = GeneratedColumn<int>(
    'weekdays',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<int> startDate = GeneratedColumn<int>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<int> endDate = GeneratedColumn<int>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxOccurrencesMeta = const VerificationMeta(
    'maxOccurrences',
  );
  @override
  late final GeneratedColumn<int> maxOccurrences = GeneratedColumn<int>(
    'max_occurrences',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentTaskId,
    recurrenceType,
    interval,
    weekdays,
    startDate,
    endDate,
    maxOccurrences,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_recurrence_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRecurrenceRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_task_id')) {
      context.handle(
        _parentTaskIdMeta,
        parentTaskId.isAcceptableOrUnknown(
          data['parent_task_id']!,
          _parentTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_type')) {
      context.handle(
        _recurrenceTypeMeta,
        recurrenceType.isAcceptableOrUnknown(
          data['recurrence_type']!,
          _recurrenceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recurrenceTypeMeta);
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    }
    if (data.containsKey('weekdays')) {
      context.handle(
        _weekdaysMeta,
        weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('max_occurrences')) {
      context.handle(
        _maxOccurrencesMeta,
        maxOccurrences.isAcceptableOrUnknown(
          data['max_occurrences']!,
          _maxOccurrencesMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRecurrenceRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRecurrenceRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_task_id'],
      ),
      recurrenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_type'],
      )!,
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval'],
      )!,
      weekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekdays'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_date'],
      ),
      maxOccurrences: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_occurrences'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TaskRecurrenceRulesTable createAlias(String alias) {
    return $TaskRecurrenceRulesTable(attachedDatabase, alias);
  }
}

class TaskRecurrenceRuleRow extends DataClass
    implements Insertable<TaskRecurrenceRuleRow> {
  final String id;

  /// The parent/template task this rule belongs to.
  final String? parentTaskId;

  /// Recurrence type: 'daily', 'weekly', 'monthly', 'custom'.
  final String recurrenceType;

  /// Interval: every N days/weeks/months.
  final int interval;

  /// Bitmask of weekdays for weekly recurrence (bit 0 = Sunday, etc.).
  /// Null for daily/monthly/custom.
  final int? weekdays;

  /// Start date (epoch ms, date only).
  final int startDate;

  /// End date (epoch ms, date only), or null for no end.
  final int? endDate;

  /// Maximum number of occurrences to generate, or null for unlimited.
  final int? maxOccurrences;

  /// Whether generation is enabled. Stopping a rule sets this to false while
  /// preserving every already-generated occurrence.
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  const TaskRecurrenceRuleRow({
    required this.id,
    this.parentTaskId,
    required this.recurrenceType,
    required this.interval,
    this.weekdays,
    required this.startDate,
    this.endDate,
    this.maxOccurrences,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<String>(parentTaskId);
    }
    map['recurrence_type'] = Variable<String>(recurrenceType);
    map['interval'] = Variable<int>(interval);
    if (!nullToAbsent || weekdays != null) {
      map['weekdays'] = Variable<int>(weekdays);
    }
    map['start_date'] = Variable<int>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<int>(endDate);
    }
    if (!nullToAbsent || maxOccurrences != null) {
      map['max_occurrences'] = Variable<int>(maxOccurrences);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TaskRecurrenceRulesCompanion toCompanion(bool nullToAbsent) {
    return TaskRecurrenceRulesCompanion(
      id: Value(id),
      parentTaskId: parentTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTaskId),
      recurrenceType: Value(recurrenceType),
      interval: Value(interval),
      weekdays: weekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdays),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      maxOccurrences: maxOccurrences == null && nullToAbsent
          ? const Value.absent()
          : Value(maxOccurrences),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TaskRecurrenceRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRecurrenceRuleRow(
      id: serializer.fromJson<String>(json['id']),
      parentTaskId: serializer.fromJson<String?>(json['parentTaskId']),
      recurrenceType: serializer.fromJson<String>(json['recurrenceType']),
      interval: serializer.fromJson<int>(json['interval']),
      weekdays: serializer.fromJson<int?>(json['weekdays']),
      startDate: serializer.fromJson<int>(json['startDate']),
      endDate: serializer.fromJson<int?>(json['endDate']),
      maxOccurrences: serializer.fromJson<int?>(json['maxOccurrences']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentTaskId': serializer.toJson<String?>(parentTaskId),
      'recurrenceType': serializer.toJson<String>(recurrenceType),
      'interval': serializer.toJson<int>(interval),
      'weekdays': serializer.toJson<int?>(weekdays),
      'startDate': serializer.toJson<int>(startDate),
      'endDate': serializer.toJson<int?>(endDate),
      'maxOccurrences': serializer.toJson<int?>(maxOccurrences),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TaskRecurrenceRuleRow copyWith({
    String? id,
    Value<String?> parentTaskId = const Value.absent(),
    String? recurrenceType,
    int? interval,
    Value<int?> weekdays = const Value.absent(),
    int? startDate,
    Value<int?> endDate = const Value.absent(),
    Value<int?> maxOccurrences = const Value.absent(),
    bool? isActive,
    int? createdAt,
    int? updatedAt,
  }) => TaskRecurrenceRuleRow(
    id: id ?? this.id,
    parentTaskId: parentTaskId.present ? parentTaskId.value : this.parentTaskId,
    recurrenceType: recurrenceType ?? this.recurrenceType,
    interval: interval ?? this.interval,
    weekdays: weekdays.present ? weekdays.value : this.weekdays,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    maxOccurrences: maxOccurrences.present
        ? maxOccurrences.value
        : this.maxOccurrences,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TaskRecurrenceRuleRow copyWithCompanion(TaskRecurrenceRulesCompanion data) {
    return TaskRecurrenceRuleRow(
      id: data.id.present ? data.id.value : this.id,
      parentTaskId: data.parentTaskId.present
          ? data.parentTaskId.value
          : this.parentTaskId,
      recurrenceType: data.recurrenceType.present
          ? data.recurrenceType.value
          : this.recurrenceType,
      interval: data.interval.present ? data.interval.value : this.interval,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      maxOccurrences: data.maxOccurrences.present
          ? data.maxOccurrences.value
          : this.maxOccurrences,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRecurrenceRuleRow(')
          ..write('id: $id, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('recurrenceType: $recurrenceType, ')
          ..write('interval: $interval, ')
          ..write('weekdays: $weekdays, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('maxOccurrences: $maxOccurrences, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    parentTaskId,
    recurrenceType,
    interval,
    weekdays,
    startDate,
    endDate,
    maxOccurrences,
    isActive,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRecurrenceRuleRow &&
          other.id == this.id &&
          other.parentTaskId == this.parentTaskId &&
          other.recurrenceType == this.recurrenceType &&
          other.interval == this.interval &&
          other.weekdays == this.weekdays &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.maxOccurrences == this.maxOccurrences &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TaskRecurrenceRulesCompanion
    extends UpdateCompanion<TaskRecurrenceRuleRow> {
  final Value<String> id;
  final Value<String?> parentTaskId;
  final Value<String> recurrenceType;
  final Value<int> interval;
  final Value<int?> weekdays;
  final Value<int> startDate;
  final Value<int?> endDate;
  final Value<int?> maxOccurrences;
  final Value<bool> isActive;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TaskRecurrenceRulesCompanion({
    this.id = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.recurrenceType = const Value.absent(),
    this.interval = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.maxOccurrences = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskRecurrenceRulesCompanion.insert({
    required String id,
    this.parentTaskId = const Value.absent(),
    required String recurrenceType,
    this.interval = const Value.absent(),
    this.weekdays = const Value.absent(),
    required int startDate,
    this.endDate = const Value.absent(),
    this.maxOccurrences = const Value.absent(),
    this.isActive = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recurrenceType = Value(recurrenceType),
       startDate = Value(startDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskRecurrenceRuleRow> custom({
    Expression<String>? id,
    Expression<String>? parentTaskId,
    Expression<String>? recurrenceType,
    Expression<int>? interval,
    Expression<int>? weekdays,
    Expression<int>? startDate,
    Expression<int>? endDate,
    Expression<int>? maxOccurrences,
    Expression<bool>? isActive,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (recurrenceType != null) 'recurrence_type': recurrenceType,
      if (interval != null) 'interval': interval,
      if (weekdays != null) 'weekdays': weekdays,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (maxOccurrences != null) 'max_occurrences': maxOccurrences,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskRecurrenceRulesCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentTaskId,
    Value<String>? recurrenceType,
    Value<int>? interval,
    Value<int?>? weekdays,
    Value<int>? startDate,
    Value<int?>? endDate,
    Value<int?>? maxOccurrences,
    Value<bool>? isActive,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TaskRecurrenceRulesCompanion(
      id: id ?? this.id,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<String>(parentTaskId.value);
    }
    if (recurrenceType.present) {
      map['recurrence_type'] = Variable<String>(recurrenceType.value);
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<int>(weekdays.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<int>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<int>(endDate.value);
    }
    if (maxOccurrences.present) {
      map['max_occurrences'] = Variable<int>(maxOccurrences.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskRecurrenceRulesCompanion(')
          ..write('id: $id, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('recurrenceType: $recurrenceType, ')
          ..write('interval: $interval, ')
          ..write('weekdays: $weekdays, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('maxOccurrences: $maxOccurrences, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskOccurrencesTable extends TaskOccurrences
    with TableInfo<$TaskOccurrencesTable, TaskOccurrenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskOccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<String> ruleId = GeneratedColumn<String>(
    'rule_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_recurrence_rules (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _occurrenceDateMeta = const VerificationMeta(
    'occurrenceDate',
  );
  @override
  late final GeneratedColumn<int> occurrenceDate = GeneratedColumn<int>(
    'occurrence_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<int> dueDate = GeneratedColumn<int>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueTimeMeta = const VerificationMeta(
    'dueTime',
  );
  @override
  late final GeneratedColumn<int> dueTime = GeneratedColumn<int>(
    'due_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueTimezoneMeta = const VerificationMeta(
    'dueTimezone',
  );
  @override
  late final GeneratedColumn<String> dueTimezone = GeneratedColumn<String>(
    'due_timezone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ruleId,
    occurrenceDate,
    dueDate,
    dueTime,
    dueTimezone,
    completed,
    isDeleted,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_occurrences';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskOccurrenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    }
    if (data.containsKey('occurrence_date')) {
      context.handle(
        _occurrenceDateMeta,
        occurrenceDate.isAcceptableOrUnknown(
          data['occurrence_date']!,
          _occurrenceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceDateMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('due_time')) {
      context.handle(
        _dueTimeMeta,
        dueTime.isAcceptableOrUnknown(data['due_time']!, _dueTimeMeta),
      );
    }
    if (data.containsKey('due_timezone')) {
      context.handle(
        _dueTimezoneMeta,
        dueTimezone.isAcceptableOrUnknown(
          data['due_timezone']!,
          _dueTimezoneMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskOccurrenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskOccurrenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_id'],
      ),
      occurrenceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_date'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_date'],
      ),
      dueTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_time'],
      ),
      dueTimezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_timezone'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TaskOccurrencesTable createAlias(String alias) {
    return $TaskOccurrencesTable(attachedDatabase, alias);
  }
}

class TaskOccurrenceRow extends DataClass
    implements Insertable<TaskOccurrenceRow> {
  final String id;

  /// The recurrence rule this occurrence belongs to.
  final String? ruleId;

  /// Occurrence date (epoch ms, date only).
  final int occurrenceDate;

  /// Due date for this occurrence (epoch ms, date only), or null if none.
  final int? dueDate;

  /// Due time (seconds since midnight), or null for date-only.
  final int? dueTime;

  /// Due timezone (IANA ID), or null for local.
  final String? dueTimezone;

  /// Whether this occurrence is completed.
  final bool completed;

  /// Whether this occurrence was manually deleted (soft delete).
  final bool isDeleted;
  final int createdAt;
  final int updatedAt;
  const TaskOccurrenceRow({
    required this.id,
    this.ruleId,
    required this.occurrenceDate,
    this.dueDate,
    this.dueTime,
    this.dueTimezone,
    required this.completed,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ruleId != null) {
      map['rule_id'] = Variable<String>(ruleId);
    }
    map['occurrence_date'] = Variable<int>(occurrenceDate);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<int>(dueDate);
    }
    if (!nullToAbsent || dueTime != null) {
      map['due_time'] = Variable<int>(dueTime);
    }
    if (!nullToAbsent || dueTimezone != null) {
      map['due_timezone'] = Variable<String>(dueTimezone);
    }
    map['completed'] = Variable<bool>(completed);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TaskOccurrencesCompanion toCompanion(bool nullToAbsent) {
    return TaskOccurrencesCompanion(
      id: Value(id),
      ruleId: ruleId == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleId),
      occurrenceDate: Value(occurrenceDate),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      dueTime: dueTime == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTime),
      dueTimezone: dueTimezone == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTimezone),
      completed: Value(completed),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TaskOccurrenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskOccurrenceRow(
      id: serializer.fromJson<String>(json['id']),
      ruleId: serializer.fromJson<String?>(json['ruleId']),
      occurrenceDate: serializer.fromJson<int>(json['occurrenceDate']),
      dueDate: serializer.fromJson<int?>(json['dueDate']),
      dueTime: serializer.fromJson<int?>(json['dueTime']),
      dueTimezone: serializer.fromJson<String?>(json['dueTimezone']),
      completed: serializer.fromJson<bool>(json['completed']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ruleId': serializer.toJson<String?>(ruleId),
      'occurrenceDate': serializer.toJson<int>(occurrenceDate),
      'dueDate': serializer.toJson<int?>(dueDate),
      'dueTime': serializer.toJson<int?>(dueTime),
      'dueTimezone': serializer.toJson<String?>(dueTimezone),
      'completed': serializer.toJson<bool>(completed),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TaskOccurrenceRow copyWith({
    String? id,
    Value<String?> ruleId = const Value.absent(),
    int? occurrenceDate,
    Value<int?> dueDate = const Value.absent(),
    Value<int?> dueTime = const Value.absent(),
    Value<String?> dueTimezone = const Value.absent(),
    bool? completed,
    bool? isDeleted,
    int? createdAt,
    int? updatedAt,
  }) => TaskOccurrenceRow(
    id: id ?? this.id,
    ruleId: ruleId.present ? ruleId.value : this.ruleId,
    occurrenceDate: occurrenceDate ?? this.occurrenceDate,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    dueTime: dueTime.present ? dueTime.value : this.dueTime,
    dueTimezone: dueTimezone.present ? dueTimezone.value : this.dueTimezone,
    completed: completed ?? this.completed,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TaskOccurrenceRow copyWithCompanion(TaskOccurrencesCompanion data) {
    return TaskOccurrenceRow(
      id: data.id.present ? data.id.value : this.id,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      occurrenceDate: data.occurrenceDate.present
          ? data.occurrenceDate.value
          : this.occurrenceDate,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      dueTime: data.dueTime.present ? data.dueTime.value : this.dueTime,
      dueTimezone: data.dueTimezone.present
          ? data.dueTimezone.value
          : this.dueTimezone,
      completed: data.completed.present ? data.completed.value : this.completed,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskOccurrenceRow(')
          ..write('id: $id, ')
          ..write('ruleId: $ruleId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueTime: $dueTime, ')
          ..write('dueTimezone: $dueTimezone, ')
          ..write('completed: $completed, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ruleId,
    occurrenceDate,
    dueDate,
    dueTime,
    dueTimezone,
    completed,
    isDeleted,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskOccurrenceRow &&
          other.id == this.id &&
          other.ruleId == this.ruleId &&
          other.occurrenceDate == this.occurrenceDate &&
          other.dueDate == this.dueDate &&
          other.dueTime == this.dueTime &&
          other.dueTimezone == this.dueTimezone &&
          other.completed == this.completed &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TaskOccurrencesCompanion extends UpdateCompanion<TaskOccurrenceRow> {
  final Value<String> id;
  final Value<String?> ruleId;
  final Value<int> occurrenceDate;
  final Value<int?> dueDate;
  final Value<int?> dueTime;
  final Value<String?> dueTimezone;
  final Value<bool> completed;
  final Value<bool> isDeleted;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TaskOccurrencesCompanion({
    this.id = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.dueTimezone = const Value.absent(),
    this.completed = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskOccurrencesCompanion.insert({
    required String id,
    this.ruleId = const Value.absent(),
    required int occurrenceDate,
    this.dueDate = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.dueTimezone = const Value.absent(),
    this.completed = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       occurrenceDate = Value(occurrenceDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskOccurrenceRow> custom({
    Expression<String>? id,
    Expression<String>? ruleId,
    Expression<int>? occurrenceDate,
    Expression<int>? dueDate,
    Expression<int>? dueTime,
    Expression<String>? dueTimezone,
    Expression<bool>? completed,
    Expression<bool>? isDeleted,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ruleId != null) 'rule_id': ruleId,
      if (occurrenceDate != null) 'occurrence_date': occurrenceDate,
      if (dueDate != null) 'due_date': dueDate,
      if (dueTime != null) 'due_time': dueTime,
      if (dueTimezone != null) 'due_timezone': dueTimezone,
      if (completed != null) 'completed': completed,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskOccurrencesCompanion copyWith({
    Value<String>? id,
    Value<String?>? ruleId,
    Value<int>? occurrenceDate,
    Value<int?>? dueDate,
    Value<int?>? dueTime,
    Value<String?>? dueTimezone,
    Value<bool>? completed,
    Value<bool>? isDeleted,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TaskOccurrencesCompanion(
      id: id ?? this.id,
      ruleId: ruleId ?? this.ruleId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      dueTimezone: dueTimezone ?? this.dueTimezone,
      completed: completed ?? this.completed,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<String>(ruleId.value);
    }
    if (occurrenceDate.present) {
      map['occurrence_date'] = Variable<int>(occurrenceDate.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<int>(dueDate.value);
    }
    if (dueTime.present) {
      map['due_time'] = Variable<int>(dueTime.value);
    }
    if (dueTimezone.present) {
      map['due_timezone'] = Variable<String>(dueTimezone.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskOccurrencesCompanion(')
          ..write('id: $id, ')
          ..write('ruleId: $ruleId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueTime: $dueTime, ')
          ..write('dueTimezone: $dueTimezone, ')
          ..write('completed: $completed, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scheduleTypeMeta = const VerificationMeta(
    'scheduleType',
  );
  @override
  late final GeneratedColumn<String> scheduleType = GeneratedColumn<String>(
    'schedule_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneIdMeta = const VerificationMeta(
    'timezoneId',
  );
  @override
  late final GeneratedColumn<String> timezoneId = GeneratedColumn<String>(
    'timezone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledAtUtcMsMeta = const VerificationMeta(
    'scheduledAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> scheduledAtUtcMs = GeneratedColumn<int>(
    'scheduled_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localTimeSecondsMeta = const VerificationMeta(
    'localTimeSeconds',
  );
  @override
  late final GeneratedColumn<int> localTimeSeconds = GeneratedColumn<int>(
    'local_time_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
    'interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _weekdaysMeta = const VerificationMeta(
    'weekdays',
  );
  @override
  late final GeneratedColumn<int> weekdays = GeneratedColumn<int>(
    'weekdays',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<int> startDate = GeneratedColumn<int>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<int> endDate = GeneratedColumn<int>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxOccurrencesMeta = const VerificationMeta(
    'maxOccurrences',
  );
  @override
  late final GeneratedColumn<int> maxOccurrences = GeneratedColumn<int>(
    'max_occurrences',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('scheduled'),
  );
  static const VerificationMeta _cancellationReasonMeta =
      const VerificationMeta('cancellationReason');
  @override
  late final GeneratedColumn<String> cancellationReason =
      GeneratedColumn<String>(
        'cancellation_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cancelledAtMsMeta = const VerificationMeta(
    'cancelledAtMs',
  );
  @override
  late final GeneratedColumn<int> cancelledAtMs = GeneratedColumn<int>(
    'cancelled_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    scheduleType,
    timezoneId,
    scheduledAtUtcMs,
    localTimeSeconds,
    interval,
    weekdays,
    startDate,
    endDate,
    maxOccurrences,
    status,
    cancellationReason,
    cancelledAtMs,
    createdAtMs,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('schedule_type')) {
      context.handle(
        _scheduleTypeMeta,
        scheduleType.isAcceptableOrUnknown(
          data['schedule_type']!,
          _scheduleTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleTypeMeta);
    }
    if (data.containsKey('timezone_id')) {
      context.handle(
        _timezoneIdMeta,
        timezoneId.isAcceptableOrUnknown(data['timezone_id']!, _timezoneIdMeta),
      );
    }
    if (data.containsKey('scheduled_at_utc_ms')) {
      context.handle(
        _scheduledAtUtcMsMeta,
        scheduledAtUtcMs.isAcceptableOrUnknown(
          data['scheduled_at_utc_ms']!,
          _scheduledAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('local_time_seconds')) {
      context.handle(
        _localTimeSecondsMeta,
        localTimeSeconds.isAcceptableOrUnknown(
          data['local_time_seconds']!,
          _localTimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    }
    if (data.containsKey('weekdays')) {
      context.handle(
        _weekdaysMeta,
        weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('max_occurrences')) {
      context.handle(
        _maxOccurrencesMeta,
        maxOccurrences.isAcceptableOrUnknown(
          data['max_occurrences']!,
          _maxOccurrencesMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('cancellation_reason')) {
      context.handle(
        _cancellationReasonMeta,
        cancellationReason.isAcceptableOrUnknown(
          data['cancellation_reason']!,
          _cancellationReasonMeta,
        ),
      );
    }
    if (data.containsKey('cancelled_at_ms')) {
      context.handle(
        _cancelledAtMsMeta,
        cancelledAtMs.isAcceptableOrUnknown(
          data['cancelled_at_ms']!,
          _cancelledAtMsMeta,
        ),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      scheduleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_type'],
      )!,
      timezoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone_id'],
      ),
      scheduledAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_at_utc_ms'],
      ),
      localTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_time_seconds'],
      ),
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval'],
      )!,
      weekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekdays'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_date'],
      ),
      maxOccurrences: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_occurrences'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      cancellationReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cancellation_reason'],
      ),
      cancelledAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cancelled_at_ms'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  final String id;
  final String taskId;

  /// One of `once`, `daily`, `weekly`, `monthly`, or `custom`.
  final String scheduleType;

  /// IANA timezone identifier (for example `America/New_York`). Null means
  /// the device-local timezone. Recurring schedules persist this so later
  /// scheduling can resolve local time across DST transitions.
  final String? timezoneId;

  /// Absolute trigger instant for a one-time reminder, in UTC epoch ms.
  final int? scheduledAtUtcMs;

  /// Local wall-clock time for recurring reminders, as seconds since local
  /// midnight (0-86399).
  final int? localTimeSeconds;

  /// Every N days/weeks/months for recurring schedules.
  final int interval;

  /// Weekly weekday bitmask (bit 0 = Sunday). Null for other schedule types.
  final int? weekdays;

  /// First eligible local calendar date for a recurring schedule, stored as
  /// UTC-midnight epoch ms so the calendar date survives timezone changes.
  final int? startDate;

  /// Last eligible local calendar date, stored as UTC-midnight epoch ms.
  final int? endDate;

  /// Maximum number of reminder occurrences, or null for no explicit cap.
  final int? maxOccurrences;

  /// One of `scheduled` or `cancelled`.
  final String status;

  /// Why a reminder was cancelled: `user` or `taskCompleted`.
  final String? cancellationReason;
  final int? cancelledAtMs;
  final int createdAtMs;
  final int updatedAtMs;
  const ReminderRow({
    required this.id,
    required this.taskId,
    required this.scheduleType,
    this.timezoneId,
    this.scheduledAtUtcMs,
    this.localTimeSeconds,
    required this.interval,
    this.weekdays,
    this.startDate,
    this.endDate,
    this.maxOccurrences,
    required this.status,
    this.cancellationReason,
    this.cancelledAtMs,
    required this.createdAtMs,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['schedule_type'] = Variable<String>(scheduleType);
    if (!nullToAbsent || timezoneId != null) {
      map['timezone_id'] = Variable<String>(timezoneId);
    }
    if (!nullToAbsent || scheduledAtUtcMs != null) {
      map['scheduled_at_utc_ms'] = Variable<int>(scheduledAtUtcMs);
    }
    if (!nullToAbsent || localTimeSeconds != null) {
      map['local_time_seconds'] = Variable<int>(localTimeSeconds);
    }
    map['interval'] = Variable<int>(interval);
    if (!nullToAbsent || weekdays != null) {
      map['weekdays'] = Variable<int>(weekdays);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<int>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<int>(endDate);
    }
    if (!nullToAbsent || maxOccurrences != null) {
      map['max_occurrences'] = Variable<int>(maxOccurrences);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || cancellationReason != null) {
      map['cancellation_reason'] = Variable<String>(cancellationReason);
    }
    if (!nullToAbsent || cancelledAtMs != null) {
      map['cancelled_at_ms'] = Variable<int>(cancelledAtMs);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      taskId: Value(taskId),
      scheduleType: Value(scheduleType),
      timezoneId: timezoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(timezoneId),
      scheduledAtUtcMs: scheduledAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledAtUtcMs),
      localTimeSeconds: localTimeSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(localTimeSeconds),
      interval: Value(interval),
      weekdays: weekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdays),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      maxOccurrences: maxOccurrences == null && nullToAbsent
          ? const Value.absent()
          : Value(maxOccurrences),
      status: Value(status),
      cancellationReason: cancellationReason == null && nullToAbsent
          ? const Value.absent()
          : Value(cancellationReason),
      cancelledAtMs: cancelledAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledAtMs),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      scheduleType: serializer.fromJson<String>(json['scheduleType']),
      timezoneId: serializer.fromJson<String?>(json['timezoneId']),
      scheduledAtUtcMs: serializer.fromJson<int?>(json['scheduledAtUtcMs']),
      localTimeSeconds: serializer.fromJson<int?>(json['localTimeSeconds']),
      interval: serializer.fromJson<int>(json['interval']),
      weekdays: serializer.fromJson<int?>(json['weekdays']),
      startDate: serializer.fromJson<int?>(json['startDate']),
      endDate: serializer.fromJson<int?>(json['endDate']),
      maxOccurrences: serializer.fromJson<int?>(json['maxOccurrences']),
      status: serializer.fromJson<String>(json['status']),
      cancellationReason: serializer.fromJson<String?>(
        json['cancellationReason'],
      ),
      cancelledAtMs: serializer.fromJson<int?>(json['cancelledAtMs']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'scheduleType': serializer.toJson<String>(scheduleType),
      'timezoneId': serializer.toJson<String?>(timezoneId),
      'scheduledAtUtcMs': serializer.toJson<int?>(scheduledAtUtcMs),
      'localTimeSeconds': serializer.toJson<int?>(localTimeSeconds),
      'interval': serializer.toJson<int>(interval),
      'weekdays': serializer.toJson<int?>(weekdays),
      'startDate': serializer.toJson<int?>(startDate),
      'endDate': serializer.toJson<int?>(endDate),
      'maxOccurrences': serializer.toJson<int?>(maxOccurrences),
      'status': serializer.toJson<String>(status),
      'cancellationReason': serializer.toJson<String?>(cancellationReason),
      'cancelledAtMs': serializer.toJson<int?>(cancelledAtMs),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  ReminderRow copyWith({
    String? id,
    String? taskId,
    String? scheduleType,
    Value<String?> timezoneId = const Value.absent(),
    Value<int?> scheduledAtUtcMs = const Value.absent(),
    Value<int?> localTimeSeconds = const Value.absent(),
    int? interval,
    Value<int?> weekdays = const Value.absent(),
    Value<int?> startDate = const Value.absent(),
    Value<int?> endDate = const Value.absent(),
    Value<int?> maxOccurrences = const Value.absent(),
    String? status,
    Value<String?> cancellationReason = const Value.absent(),
    Value<int?> cancelledAtMs = const Value.absent(),
    int? createdAtMs,
    int? updatedAtMs,
  }) => ReminderRow(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    scheduleType: scheduleType ?? this.scheduleType,
    timezoneId: timezoneId.present ? timezoneId.value : this.timezoneId,
    scheduledAtUtcMs: scheduledAtUtcMs.present
        ? scheduledAtUtcMs.value
        : this.scheduledAtUtcMs,
    localTimeSeconds: localTimeSeconds.present
        ? localTimeSeconds.value
        : this.localTimeSeconds,
    interval: interval ?? this.interval,
    weekdays: weekdays.present ? weekdays.value : this.weekdays,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    maxOccurrences: maxOccurrences.present
        ? maxOccurrences.value
        : this.maxOccurrences,
    status: status ?? this.status,
    cancellationReason: cancellationReason.present
        ? cancellationReason.value
        : this.cancellationReason,
    cancelledAtMs: cancelledAtMs.present
        ? cancelledAtMs.value
        : this.cancelledAtMs,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      scheduleType: data.scheduleType.present
          ? data.scheduleType.value
          : this.scheduleType,
      timezoneId: data.timezoneId.present
          ? data.timezoneId.value
          : this.timezoneId,
      scheduledAtUtcMs: data.scheduledAtUtcMs.present
          ? data.scheduledAtUtcMs.value
          : this.scheduledAtUtcMs,
      localTimeSeconds: data.localTimeSeconds.present
          ? data.localTimeSeconds.value
          : this.localTimeSeconds,
      interval: data.interval.present ? data.interval.value : this.interval,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      maxOccurrences: data.maxOccurrences.present
          ? data.maxOccurrences.value
          : this.maxOccurrences,
      status: data.status.present ? data.status.value : this.status,
      cancellationReason: data.cancellationReason.present
          ? data.cancellationReason.value
          : this.cancellationReason,
      cancelledAtMs: data.cancelledAtMs.present
          ? data.cancelledAtMs.value
          : this.cancelledAtMs,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('scheduledAtUtcMs: $scheduledAtUtcMs, ')
          ..write('localTimeSeconds: $localTimeSeconds, ')
          ..write('interval: $interval, ')
          ..write('weekdays: $weekdays, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('maxOccurrences: $maxOccurrences, ')
          ..write('status: $status, ')
          ..write('cancellationReason: $cancellationReason, ')
          ..write('cancelledAtMs: $cancelledAtMs, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    scheduleType,
    timezoneId,
    scheduledAtUtcMs,
    localTimeSeconds,
    interval,
    weekdays,
    startDate,
    endDate,
    maxOccurrences,
    status,
    cancellationReason,
    cancelledAtMs,
    createdAtMs,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.scheduleType == this.scheduleType &&
          other.timezoneId == this.timezoneId &&
          other.scheduledAtUtcMs == this.scheduledAtUtcMs &&
          other.localTimeSeconds == this.localTimeSeconds &&
          other.interval == this.interval &&
          other.weekdays == this.weekdays &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.maxOccurrences == this.maxOccurrences &&
          other.status == this.status &&
          other.cancellationReason == this.cancellationReason &&
          other.cancelledAtMs == this.cancelledAtMs &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> scheduleType;
  final Value<String?> timezoneId;
  final Value<int?> scheduledAtUtcMs;
  final Value<int?> localTimeSeconds;
  final Value<int> interval;
  final Value<int?> weekdays;
  final Value<int?> startDate;
  final Value<int?> endDate;
  final Value<int?> maxOccurrences;
  final Value<String> status;
  final Value<String?> cancellationReason;
  final Value<int?> cancelledAtMs;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.scheduleType = const Value.absent(),
    this.timezoneId = const Value.absent(),
    this.scheduledAtUtcMs = const Value.absent(),
    this.localTimeSeconds = const Value.absent(),
    this.interval = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.maxOccurrences = const Value.absent(),
    this.status = const Value.absent(),
    this.cancellationReason = const Value.absent(),
    this.cancelledAtMs = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String taskId,
    required String scheduleType,
    this.timezoneId = const Value.absent(),
    this.scheduledAtUtcMs = const Value.absent(),
    this.localTimeSeconds = const Value.absent(),
    this.interval = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.maxOccurrences = const Value.absent(),
    this.status = const Value.absent(),
    this.cancellationReason = const Value.absent(),
    this.cancelledAtMs = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       scheduleType = Value(scheduleType),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<ReminderRow> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? scheduleType,
    Expression<String>? timezoneId,
    Expression<int>? scheduledAtUtcMs,
    Expression<int>? localTimeSeconds,
    Expression<int>? interval,
    Expression<int>? weekdays,
    Expression<int>? startDate,
    Expression<int>? endDate,
    Expression<int>? maxOccurrences,
    Expression<String>? status,
    Expression<String>? cancellationReason,
    Expression<int>? cancelledAtMs,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (scheduleType != null) 'schedule_type': scheduleType,
      if (timezoneId != null) 'timezone_id': timezoneId,
      if (scheduledAtUtcMs != null) 'scheduled_at_utc_ms': scheduledAtUtcMs,
      if (localTimeSeconds != null) 'local_time_seconds': localTimeSeconds,
      if (interval != null) 'interval': interval,
      if (weekdays != null) 'weekdays': weekdays,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (maxOccurrences != null) 'max_occurrences': maxOccurrences,
      if (status != null) 'status': status,
      if (cancellationReason != null) 'cancellation_reason': cancellationReason,
      if (cancelledAtMs != null) 'cancelled_at_ms': cancelledAtMs,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? scheduleType,
    Value<String?>? timezoneId,
    Value<int?>? scheduledAtUtcMs,
    Value<int?>? localTimeSeconds,
    Value<int>? interval,
    Value<int?>? weekdays,
    Value<int?>? startDate,
    Value<int?>? endDate,
    Value<int?>? maxOccurrences,
    Value<String>? status,
    Value<String?>? cancellationReason,
    Value<int?>? cancelledAtMs,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      scheduleType: scheduleType ?? this.scheduleType,
      timezoneId: timezoneId ?? this.timezoneId,
      scheduledAtUtcMs: scheduledAtUtcMs ?? this.scheduledAtUtcMs,
      localTimeSeconds: localTimeSeconds ?? this.localTimeSeconds,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAtMs: cancelledAtMs ?? this.cancelledAtMs,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (scheduleType.present) {
      map['schedule_type'] = Variable<String>(scheduleType.value);
    }
    if (timezoneId.present) {
      map['timezone_id'] = Variable<String>(timezoneId.value);
    }
    if (scheduledAtUtcMs.present) {
      map['scheduled_at_utc_ms'] = Variable<int>(scheduledAtUtcMs.value);
    }
    if (localTimeSeconds.present) {
      map['local_time_seconds'] = Variable<int>(localTimeSeconds.value);
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<int>(weekdays.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<int>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<int>(endDate.value);
    }
    if (maxOccurrences.present) {
      map['max_occurrences'] = Variable<int>(maxOccurrences.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (cancellationReason.present) {
      map['cancellation_reason'] = Variable<String>(cancellationReason.value);
    }
    if (cancelledAtMs.present) {
      map['cancelled_at_ms'] = Variable<int>(cancelledAtMs.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('scheduledAtUtcMs: $scheduledAtUtcMs, ')
          ..write('localTimeSeconds: $localTimeSeconds, ')
          ..write('interval: $interval, ')
          ..write('weekdays: $weekdays, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('maxOccurrences: $maxOccurrences, ')
          ..write('status: $status, ')
          ..write('cancellationReason: $cancellationReason, ')
          ..write('cancelledAtMs: $cancelledAtMs, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SystumDatabase extends GeneratedDatabase {
  _$SystumDatabase(QueryExecutor e) : super(e);
  $SystumDatabaseManager get managers => $SystumDatabaseManager(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $FocusSessionsTable focusSessions = $FocusSessionsTable(this);
  late final $FocusSessionIntervalsTable focusSessionIntervals =
      $FocusSessionIntervalsTable(this);
  late final $TaskRecurrenceRulesTable taskRecurrenceRules =
      $TaskRecurrenceRulesTable(this);
  late final $TaskOccurrencesTable taskOccurrences = $TaskOccurrencesTable(
    this,
  );
  late final $RemindersTable reminders = $RemindersTable(this);
  late final Index tasksGoalIdIdx = Index(
    'tasks_goal_id_idx',
    'CREATE INDEX tasks_goal_id_idx ON tasks (goal_id)',
  );
  late final Index tasksParentTaskIdIdx = Index(
    'tasks_parent_task_id_idx',
    'CREATE INDEX tasks_parent_task_id_idx ON tasks (parent_task_id)',
  );
  late final Index taskRecurrenceRulesParentTaskIdIdx = Index(
    'task_recurrence_rules_parent_task_id_idx',
    'CREATE INDEX task_recurrence_rules_parent_task_id_idx ON task_recurrence_rules (parent_task_id)',
  );
  late final Index taskRecurrenceRulesParentUniqueIdx = Index(
    'task_recurrence_rules_parent_unique_idx',
    'CREATE UNIQUE INDEX task_recurrence_rules_parent_unique_idx ON task_recurrence_rules (parent_task_id)',
  );
  late final Index taskOccurrencesRuleIdIdx = Index(
    'task_occurrences_rule_id_idx',
    'CREATE INDEX task_occurrences_rule_id_idx ON task_occurrences (rule_id)',
  );
  late final Index taskOccurrencesOccurrenceDateIdx = Index(
    'task_occurrences_occurrence_date_idx',
    'CREATE INDEX task_occurrences_occurrence_date_idx ON task_occurrences (occurrence_date)',
  );
  late final Index taskOccurrencesRuleDateUniqueIdx = Index(
    'task_occurrences_rule_date_unique_idx',
    'CREATE UNIQUE INDEX task_occurrences_rule_date_unique_idx ON task_occurrences (rule_id, occurrence_date)',
  );
  late final Index remindersTaskIdIdx = Index(
    'reminders_task_id_idx',
    'CREATE INDEX reminders_task_id_idx ON reminders (task_id)',
  );
  late final Index remindersStatusIdx = Index(
    'reminders_status_idx',
    'CREATE INDEX reminders_status_idx ON reminders (status)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    goals,
    tasks,
    focusSessions,
    focusSessionIntervals,
    taskRecurrenceRules,
    taskOccurrences,
    reminders,
    tasksGoalIdIdx,
    tasksParentTaskIdIdx,
    taskRecurrenceRulesParentTaskIdIdx,
    taskRecurrenceRulesParentUniqueIdx,
    taskOccurrencesRuleIdIdx,
    taskOccurrencesOccurrenceDateIdx,
    taskOccurrencesRuleDateUniqueIdx,
    remindersTaskIdIdx,
    remindersStatusIdx,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('focus_sessions', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_recurrence_rules', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'task_recurrence_rules',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_occurrences', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminders', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$GoalsTableCreateCompanionBuilder =
    GoalsCompanion Function({
      required String id,
      required String title,
      Value<String?> description,
      Value<GoalDate?> targetDate,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GoalsTableUpdateCompanionBuilder =
    GoalsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<GoalDate?> targetDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$GoalsTableReferences
    extends BaseReferences<_$SystumDatabase, $GoalsTable, GoalRow> {
  $$GoalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TasksTable, List<TaskRow>> _tasksRefsTable(
    _$SystumDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'goals__id__tasks__goal_id',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GoalsTableFilterComposer
    extends Composer<_$SystumDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<GoalDate?, GoalDate, int> get targetDate =>
      $composableBuilder(
        column: $table.targetDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableOrderingComposer
    extends Composer<_$SystumDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$SystumDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<GoalDate?, int> get targetDate =>
      $composableBuilder(
        column: $table.targetDate,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$SystumDatabase,
          $GoalsTable,
          GoalRow,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (GoalRow, $$GoalsTableReferences),
          GoalRow,
          PrefetchHooks Function({bool tasksRefs})
        > {
  $$GoalsTableTableManager(_$SystumDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<GoalDate?> targetDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                title: title,
                description: description,
                targetDate: targetDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<GoalDate?> targetDate = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion.insert(
                id: id,
                title: title,
                description: description,
                targetDate: targetDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GoalsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({tasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tasksRefs) db.tasks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tasksRefs)
                    await $_getPrefetchedData<GoalRow, $GoalsTable, TaskRow>(
                      currentTable: table,
                      referencedTable: $$GoalsTableReferences._tasksRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$GoalsTableReferences(db, table, p0).tasksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.goalId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$SystumDatabase,
      $GoalsTable,
      GoalRow,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (GoalRow, $$GoalsTableReferences),
      GoalRow,
      PrefetchHooks Function({bool tasksRefs})
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String id,
      required String title,
      Value<String?> description,
      Value<bool> completed,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> dueDate,
      Value<int?> dueTime,
      Value<String?> dueTimezone,
      Value<int> priority,
      Value<String?> category,
      Value<String?> goalId,
      Value<String?> parentTaskId,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<bool> completed,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> dueDate,
      Value<int?> dueTime,
      Value<String?> dueTimezone,
      Value<int> priority,
      Value<String?> category,
      Value<String?> goalId,
      Value<String?> parentTaskId,
      Value<int> rowid,
    });

final class $$TasksTableReferences
    extends BaseReferences<_$SystumDatabase, $TasksTable, TaskRow> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GoalsTable _goalIdTable(_$SystumDatabase db) =>
      db.goals.createAlias('tasks__goal_id__goals__id');

  $$GoalsTableProcessedTableManager? get goalId {
    final $_column = $_itemColumn<String>('goal_id');
    if ($_column == null) return null;
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TasksTable _parentTaskIdTable(_$SystumDatabase db) =>
      db.tasks.createAlias('tasks__parent_task_id__tasks__id');

  $$TasksTableProcessedTableManager? get parentTaskId {
    final $_column = $_itemColumn<String>('parent_task_id');
    if ($_column == null) return null;
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentTaskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FocusSessionsTable, List<FocusSessionRow>>
  _focusSessionsRefsTable(_$SystumDatabase db) => MultiTypedResultKey.fromTable(
    db.focusSessions,
    aliasName: 'tasks__id__focus_sessions__task_id',
  );

  $$FocusSessionsTableProcessedTableManager get focusSessionsRefs {
    final manager = $$FocusSessionsTableTableManager(
      $_db,
      $_db.focusSessions,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_focusSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $TaskRecurrenceRulesTable,
    List<TaskRecurrenceRuleRow>
  >
  _taskRecurrenceRulesRefsTable(_$SystumDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.taskRecurrenceRules,
        aliasName: 'tasks__id__task_recurrence_rules__parent_task_id',
      );

  $$TaskRecurrenceRulesTableProcessedTableManager get taskRecurrenceRulesRefs {
    final manager = $$TaskRecurrenceRulesTableTableManager(
      $_db,
      $_db.taskRecurrenceRules,
    ).filter((f) => f.parentTaskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _taskRecurrenceRulesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$SystumDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: 'tasks__id__reminders__task_id',
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer
    extends Composer<_$SystumDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueTime => $composableBuilder(
    column: $table.dueTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueTimezone => $composableBuilder(
    column: $table.dueTimezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableFilterComposer get parentTaskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTaskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> focusSessionsRefs(
    Expression<bool> Function($$FocusSessionsTableFilterComposer f) f,
  ) {
    final $$FocusSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.focusSessions,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FocusSessionsTableFilterComposer(
            $db: $db,
            $table: $db.focusSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskRecurrenceRulesRefs(
    Expression<bool> Function($$TaskRecurrenceRulesTableFilterComposer f) f,
  ) {
    final $$TaskRecurrenceRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRecurrenceRules,
      getReferencedColumn: (t) => t.parentTaskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRecurrenceRulesTableFilterComposer(
            $db: $db,
            $table: $db.taskRecurrenceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$SystumDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueTime => $composableBuilder(
    column: $table.dueTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueTimezone => $composableBuilder(
    column: $table.dueTimezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableOrderingComposer get parentTaskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTaskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$SystumDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get dueTime =>
      $composableBuilder(column: $table.dueTime, builder: (column) => column);

  GeneratedColumn<String> get dueTimezone => $composableBuilder(
    column: $table.dueTimezone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableAnnotationComposer get parentTaskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTaskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> focusSessionsRefs<T extends Object>(
    Expression<T> Function($$FocusSessionsTableAnnotationComposer a) f,
  ) {
    final $$FocusSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.focusSessions,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FocusSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.focusSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskRecurrenceRulesRefs<T extends Object>(
    Expression<T> Function($$TaskRecurrenceRulesTableAnnotationComposer a) f,
  ) {
    final $$TaskRecurrenceRulesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.taskRecurrenceRules,
          getReferencedColumn: (t) => t.parentTaskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TaskRecurrenceRulesTableAnnotationComposer(
                $db: $db,
                $table: $db.taskRecurrenceRules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$SystumDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, $$TasksTableReferences),
          TaskRow,
          PrefetchHooks Function({
            bool goalId,
            bool parentTaskId,
            bool focusSessionsRefs,
            bool taskRecurrenceRulesRefs,
            bool remindersRefs,
          })
        > {
  $$TasksTableTableManager(_$SystumDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<int?> dueTime = const Value.absent(),
                Value<String?> dueTimezone = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<String?> parentTaskId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                title: title,
                description: description,
                completed: completed,
                createdAt: createdAt,
                updatedAt: updatedAt,
                dueDate: dueDate,
                dueTime: dueTime,
                dueTimezone: dueTimezone,
                priority: priority,
                category: category,
                goalId: goalId,
                parentTaskId: parentTaskId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> dueDate = const Value.absent(),
                Value<int?> dueTime = const Value.absent(),
                Value<String?> dueTimezone = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<String?> parentTaskId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                title: title,
                description: description,
                completed: completed,
                createdAt: createdAt,
                updatedAt: updatedAt,
                dueDate: dueDate,
                dueTime: dueTime,
                dueTimezone: dueTimezone,
                priority: priority,
                category: category,
                goalId: goalId,
                parentTaskId: parentTaskId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                goalId = false,
                parentTaskId = false,
                focusSessionsRefs = false,
                taskRecurrenceRulesRefs = false,
                remindersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (focusSessionsRefs) db.focusSessions,
                    if (taskRecurrenceRulesRefs) db.taskRecurrenceRules,
                    if (remindersRefs) db.reminders,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (goalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.goalId,
                                    referencedTable: $$TasksTableReferences
                                        ._goalIdTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._goalIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (parentTaskId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentTaskId,
                                    referencedTable: $$TasksTableReferences
                                        ._parentTaskIdTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._parentTaskIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (focusSessionsRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          FocusSessionRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._focusSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).focusSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskRecurrenceRulesRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          TaskRecurrenceRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskRecurrenceRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskRecurrenceRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.parentTaskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          ReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$SystumDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, $$TasksTableReferences),
      TaskRow,
      PrefetchHooks Function({
        bool goalId,
        bool parentTaskId,
        bool focusSessionsRefs,
        bool taskRecurrenceRulesRefs,
        bool remindersRefs,
      })
    >;
typedef $$FocusSessionsTableCreateCompanionBuilder =
    FocusSessionsCompanion Function({
      required String id,
      Value<String?> taskId,
      Value<String?> taskIdAtStart,
      Value<String?> taskTitleAtStart,
      required FocusSessionMode mode,
      required FocusSessionStatus status,
      required int startedAtMs,
      Value<int?> endedAtMs,
      Value<int?> plannedDurationMs,
      Value<int?> actualDurationMs,
      Value<String?> cycleId,
      Value<int?> cycleRound,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$FocusSessionsTableUpdateCompanionBuilder =
    FocusSessionsCompanion Function({
      Value<String> id,
      Value<String?> taskId,
      Value<String?> taskIdAtStart,
      Value<String?> taskTitleAtStart,
      Value<FocusSessionMode> mode,
      Value<FocusSessionStatus> status,
      Value<int> startedAtMs,
      Value<int?> endedAtMs,
      Value<int?> plannedDurationMs,
      Value<int?> actualDurationMs,
      Value<String?> cycleId,
      Value<int?> cycleRound,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

final class $$FocusSessionsTableReferences
    extends
        BaseReferences<_$SystumDatabase, $FocusSessionsTable, FocusSessionRow> {
  $$FocusSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$SystumDatabase db) =>
      db.tasks.createAlias('focus_sessions__task_id__tasks__id');

  $$TasksTableProcessedTableManager? get taskId {
    final $_column = $_itemColumn<String>('task_id');
    if ($_column == null) return null;
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $FocusSessionIntervalsTable,
    List<FocusSessionIntervalRow>
  >
  _focusSessionIntervalsRefsTable(_$SystumDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.focusSessionIntervals,
        aliasName: 'focus_sessions__id__focus_session_intervals__session_id',
      );

  $$FocusSessionIntervalsTableProcessedTableManager
  get focusSessionIntervalsRefs {
    final manager = $$FocusSessionIntervalsTableTableManager(
      $_db,
      $_db.focusSessionIntervals,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _focusSessionIntervalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FocusSessionsTableFilterComposer
    extends Composer<_$SystumDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskIdAtStart => $composableBuilder(
    column: $table.taskIdAtStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskTitleAtStart => $composableBuilder(
    column: $table.taskTitleAtStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FocusSessionMode, FocusSessionMode, String>
  get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<FocusSessionStatus, FocusSessionStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedDurationMs => $composableBuilder(
    column: $table.plannedDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualDurationMs => $composableBuilder(
    column: $table.actualDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycleId => $composableBuilder(
    column: $table.cycleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cycleRound => $composableBuilder(
    column: $table.cycleRound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> focusSessionIntervalsRefs(
    Expression<bool> Function($$FocusSessionIntervalsTableFilterComposer f) f,
  ) {
    final $$FocusSessionIntervalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.focusSessionIntervals,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FocusSessionIntervalsTableFilterComposer(
                $db: $db,
                $table: $db.focusSessionIntervals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FocusSessionsTableOrderingComposer
    extends Composer<_$SystumDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskIdAtStart => $composableBuilder(
    column: $table.taskIdAtStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskTitleAtStart => $composableBuilder(
    column: $table.taskTitleAtStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedDurationMs => $composableBuilder(
    column: $table.plannedDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualDurationMs => $composableBuilder(
    column: $table.actualDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleId => $composableBuilder(
    column: $table.cycleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cycleRound => $composableBuilder(
    column: $table.cycleRound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FocusSessionsTableAnnotationComposer
    extends Composer<_$SystumDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskIdAtStart => $composableBuilder(
    column: $table.taskIdAtStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskTitleAtStart => $composableBuilder(
    column: $table.taskTitleAtStart,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<FocusSessionMode, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FocusSessionStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtMs =>
      $composableBuilder(column: $table.endedAtMs, builder: (column) => column);

  GeneratedColumn<int> get plannedDurationMs => $composableBuilder(
    column: $table.plannedDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualDurationMs => $composableBuilder(
    column: $table.actualDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cycleId =>
      $composableBuilder(column: $table.cycleId, builder: (column) => column);

  GeneratedColumn<int> get cycleRound => $composableBuilder(
    column: $table.cycleRound,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> focusSessionIntervalsRefs<T extends Object>(
    Expression<T> Function($$FocusSessionIntervalsTableAnnotationComposer a) f,
  ) {
    final $$FocusSessionIntervalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.focusSessionIntervals,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FocusSessionIntervalsTableAnnotationComposer(
                $db: $db,
                $table: $db.focusSessionIntervals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FocusSessionsTableTableManager
    extends
        RootTableManager<
          _$SystumDatabase,
          $FocusSessionsTable,
          FocusSessionRow,
          $$FocusSessionsTableFilterComposer,
          $$FocusSessionsTableOrderingComposer,
          $$FocusSessionsTableAnnotationComposer,
          $$FocusSessionsTableCreateCompanionBuilder,
          $$FocusSessionsTableUpdateCompanionBuilder,
          (FocusSessionRow, $$FocusSessionsTableReferences),
          FocusSessionRow,
          PrefetchHooks Function({bool taskId, bool focusSessionIntervalsRefs})
        > {
  $$FocusSessionsTableTableManager(
    _$SystumDatabase db,
    $FocusSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> taskIdAtStart = const Value.absent(),
                Value<String?> taskTitleAtStart = const Value.absent(),
                Value<FocusSessionMode> mode = const Value.absent(),
                Value<FocusSessionStatus> status = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<int?> endedAtMs = const Value.absent(),
                Value<int?> plannedDurationMs = const Value.absent(),
                Value<int?> actualDurationMs = const Value.absent(),
                Value<String?> cycleId = const Value.absent(),
                Value<int?> cycleRound = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion(
                id: id,
                taskId: taskId,
                taskIdAtStart: taskIdAtStart,
                taskTitleAtStart: taskTitleAtStart,
                mode: mode,
                status: status,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                plannedDurationMs: plannedDurationMs,
                actualDurationMs: actualDurationMs,
                cycleId: cycleId,
                cycleRound: cycleRound,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> taskId = const Value.absent(),
                Value<String?> taskIdAtStart = const Value.absent(),
                Value<String?> taskTitleAtStart = const Value.absent(),
                required FocusSessionMode mode,
                required FocusSessionStatus status,
                required int startedAtMs,
                Value<int?> endedAtMs = const Value.absent(),
                Value<int?> plannedDurationMs = const Value.absent(),
                Value<int?> actualDurationMs = const Value.absent(),
                Value<String?> cycleId = const Value.absent(),
                Value<int?> cycleRound = const Value.absent(),
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion.insert(
                id: id,
                taskId: taskId,
                taskIdAtStart: taskIdAtStart,
                taskTitleAtStart: taskTitleAtStart,
                mode: mode,
                status: status,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                plannedDurationMs: plannedDurationMs,
                actualDurationMs: actualDurationMs,
                cycleId: cycleId,
                cycleRound: cycleRound,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FocusSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({taskId = false, focusSessionIntervalsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (focusSessionIntervalsRefs) db.focusSessionIntervals,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (taskId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.taskId,
                                    referencedTable:
                                        $$FocusSessionsTableReferences
                                            ._taskIdTable(db),
                                    referencedColumn:
                                        $$FocusSessionsTableReferences
                                            ._taskIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (focusSessionIntervalsRefs)
                        await $_getPrefetchedData<
                          FocusSessionRow,
                          $FocusSessionsTable,
                          FocusSessionIntervalRow
                        >(
                          currentTable: table,
                          referencedTable: $$FocusSessionsTableReferences
                              ._focusSessionIntervalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FocusSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).focusSessionIntervalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FocusSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$SystumDatabase,
      $FocusSessionsTable,
      FocusSessionRow,
      $$FocusSessionsTableFilterComposer,
      $$FocusSessionsTableOrderingComposer,
      $$FocusSessionsTableAnnotationComposer,
      $$FocusSessionsTableCreateCompanionBuilder,
      $$FocusSessionsTableUpdateCompanionBuilder,
      (FocusSessionRow, $$FocusSessionsTableReferences),
      FocusSessionRow,
      PrefetchHooks Function({bool taskId, bool focusSessionIntervalsRefs})
    >;
typedef $$FocusSessionIntervalsTableCreateCompanionBuilder =
    FocusSessionIntervalsCompanion Function({
      required String id,
      required String sessionId,
      required int startedAtMs,
      Value<int?> endedAtMs,
      Value<int> rowid,
    });
typedef $$FocusSessionIntervalsTableUpdateCompanionBuilder =
    FocusSessionIntervalsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> startedAtMs,
      Value<int?> endedAtMs,
      Value<int> rowid,
    });

final class $$FocusSessionIntervalsTableReferences
    extends
        BaseReferences<
          _$SystumDatabase,
          $FocusSessionIntervalsTable,
          FocusSessionIntervalRow
        > {
  $$FocusSessionIntervalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FocusSessionsTable _sessionIdTable(_$SystumDatabase db) => db
      .focusSessions
      .createAlias('focus_session_intervals__session_id__focus_sessions__id');

  $$FocusSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$FocusSessionsTableTableManager(
      $_db,
      $_db.focusSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FocusSessionIntervalsTableFilterComposer
    extends Composer<_$SystumDatabase, $FocusSessionIntervalsTable> {
  $$FocusSessionIntervalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$FocusSessionsTableFilterComposer get sessionId {
    final $$FocusSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.focusSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FocusSessionsTableFilterComposer(
            $db: $db,
            $table: $db.focusSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FocusSessionIntervalsTableOrderingComposer
    extends Composer<_$SystumDatabase, $FocusSessionIntervalsTable> {
  $$FocusSessionIntervalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$FocusSessionsTableOrderingComposer get sessionId {
    final $$FocusSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.focusSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FocusSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.focusSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FocusSessionIntervalsTableAnnotationComposer
    extends Composer<_$SystumDatabase, $FocusSessionIntervalsTable> {
  $$FocusSessionIntervalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtMs =>
      $composableBuilder(column: $table.endedAtMs, builder: (column) => column);

  $$FocusSessionsTableAnnotationComposer get sessionId {
    final $$FocusSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.focusSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FocusSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.focusSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FocusSessionIntervalsTableTableManager
    extends
        RootTableManager<
          _$SystumDatabase,
          $FocusSessionIntervalsTable,
          FocusSessionIntervalRow,
          $$FocusSessionIntervalsTableFilterComposer,
          $$FocusSessionIntervalsTableOrderingComposer,
          $$FocusSessionIntervalsTableAnnotationComposer,
          $$FocusSessionIntervalsTableCreateCompanionBuilder,
          $$FocusSessionIntervalsTableUpdateCompanionBuilder,
          (FocusSessionIntervalRow, $$FocusSessionIntervalsTableReferences),
          FocusSessionIntervalRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$FocusSessionIntervalsTableTableManager(
    _$SystumDatabase db,
    $FocusSessionIntervalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionIntervalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FocusSessionIntervalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FocusSessionIntervalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<int?> endedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionIntervalsCompanion(
                id: id,
                sessionId: sessionId,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int startedAtMs,
                Value<int?> endedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionIntervalsCompanion.insert(
                id: id,
                sessionId: sessionId,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FocusSessionIntervalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$FocusSessionIntervalsTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$FocusSessionIntervalsTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FocusSessionIntervalsTableProcessedTableManager =
    ProcessedTableManager<
      _$SystumDatabase,
      $FocusSessionIntervalsTable,
      FocusSessionIntervalRow,
      $$FocusSessionIntervalsTableFilterComposer,
      $$FocusSessionIntervalsTableOrderingComposer,
      $$FocusSessionIntervalsTableAnnotationComposer,
      $$FocusSessionIntervalsTableCreateCompanionBuilder,
      $$FocusSessionIntervalsTableUpdateCompanionBuilder,
      (FocusSessionIntervalRow, $$FocusSessionIntervalsTableReferences),
      FocusSessionIntervalRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$TaskRecurrenceRulesTableCreateCompanionBuilder =
    TaskRecurrenceRulesCompanion Function({
      required String id,
      Value<String?> parentTaskId,
      required String recurrenceType,
      Value<int> interval,
      Value<int?> weekdays,
      required int startDate,
      Value<int?> endDate,
      Value<int?> maxOccurrences,
      Value<bool> isActive,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TaskRecurrenceRulesTableUpdateCompanionBuilder =
    TaskRecurrenceRulesCompanion Function({
      Value<String> id,
      Value<String?> parentTaskId,
      Value<String> recurrenceType,
      Value<int> interval,
      Value<int?> weekdays,
      Value<int> startDate,
      Value<int?> endDate,
      Value<int?> maxOccurrences,
      Value<bool> isActive,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$TaskRecurrenceRulesTableReferences
    extends
        BaseReferences<
          _$SystumDatabase,
          $TaskRecurrenceRulesTable,
          TaskRecurrenceRuleRow
        > {
  $$TaskRecurrenceRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _parentTaskIdTable(_$SystumDatabase db) =>
      db.tasks.createAlias('task_recurrence_rules__parent_task_id__tasks__id');

  $$TasksTableProcessedTableManager? get parentTaskId {
    final $_column = $_itemColumn<String>('parent_task_id');
    if ($_column == null) return null;
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentTaskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TaskOccurrencesTable, List<TaskOccurrenceRow>>
  _taskOccurrencesRefsTable(_$SystumDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.taskOccurrences,
        aliasName: 'task_recurrence_rules__id__task_occurrences__rule_id',
      );

  $$TaskOccurrencesTableProcessedTableManager get taskOccurrencesRefs {
    final manager = $$TaskOccurrencesTableTableManager(
      $_db,
      $_db.taskOccurrences,
    ).filter((f) => f.ruleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _taskOccurrencesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TaskRecurrenceRulesTableFilterComposer
    extends Composer<_$SystumDatabase, $TaskRecurrenceRulesTable> {
  $$TaskRecurrenceRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxOccurrences => $composableBuilder(
    column: $table.maxOccurrences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get parentTaskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTaskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> taskOccurrencesRefs(
    Expression<bool> Function($$TaskOccurrencesTableFilterComposer f) f,
  ) {
    final $$TaskOccurrencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskOccurrences,
      getReferencedColumn: (t) => t.ruleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskOccurrencesTableFilterComposer(
            $db: $db,
            $table: $db.taskOccurrences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskRecurrenceRulesTableOrderingComposer
    extends Composer<_$SystumDatabase, $TaskRecurrenceRulesTable> {
  $$TaskRecurrenceRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxOccurrences => $composableBuilder(
    column: $table.maxOccurrences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get parentTaskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTaskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskRecurrenceRulesTableAnnotationComposer
    extends Composer<_$SystumDatabase, $TaskRecurrenceRulesTable> {
  $$TaskRecurrenceRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<int> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<int> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<int> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get maxOccurrences => $composableBuilder(
    column: $table.maxOccurrences,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TasksTableAnnotationComposer get parentTaskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTaskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> taskOccurrencesRefs<T extends Object>(
    Expression<T> Function($$TaskOccurrencesTableAnnotationComposer a) f,
  ) {
    final $$TaskOccurrencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskOccurrences,
      getReferencedColumn: (t) => t.ruleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskOccurrencesTableAnnotationComposer(
            $db: $db,
            $table: $db.taskOccurrences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskRecurrenceRulesTableTableManager
    extends
        RootTableManager<
          _$SystumDatabase,
          $TaskRecurrenceRulesTable,
          TaskRecurrenceRuleRow,
          $$TaskRecurrenceRulesTableFilterComposer,
          $$TaskRecurrenceRulesTableOrderingComposer,
          $$TaskRecurrenceRulesTableAnnotationComposer,
          $$TaskRecurrenceRulesTableCreateCompanionBuilder,
          $$TaskRecurrenceRulesTableUpdateCompanionBuilder,
          (TaskRecurrenceRuleRow, $$TaskRecurrenceRulesTableReferences),
          TaskRecurrenceRuleRow,
          PrefetchHooks Function({bool parentTaskId, bool taskOccurrencesRefs})
        > {
  $$TaskRecurrenceRulesTableTableManager(
    _$SystumDatabase db,
    $TaskRecurrenceRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskRecurrenceRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskRecurrenceRulesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TaskRecurrenceRulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentTaskId = const Value.absent(),
                Value<String> recurrenceType = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<int?> weekdays = const Value.absent(),
                Value<int> startDate = const Value.absent(),
                Value<int?> endDate = const Value.absent(),
                Value<int?> maxOccurrences = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRecurrenceRulesCompanion(
                id: id,
                parentTaskId: parentTaskId,
                recurrenceType: recurrenceType,
                interval: interval,
                weekdays: weekdays,
                startDate: startDate,
                endDate: endDate,
                maxOccurrences: maxOccurrences,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentTaskId = const Value.absent(),
                required String recurrenceType,
                Value<int> interval = const Value.absent(),
                Value<int?> weekdays = const Value.absent(),
                required int startDate,
                Value<int?> endDate = const Value.absent(),
                Value<int?> maxOccurrences = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TaskRecurrenceRulesCompanion.insert(
                id: id,
                parentTaskId: parentTaskId,
                recurrenceType: recurrenceType,
                interval: interval,
                weekdays: weekdays,
                startDate: startDate,
                endDate: endDate,
                maxOccurrences: maxOccurrences,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskRecurrenceRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({parentTaskId = false, taskOccurrencesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskOccurrencesRefs) db.taskOccurrences,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parentTaskId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentTaskId,
                                    referencedTable:
                                        $$TaskRecurrenceRulesTableReferences
                                            ._parentTaskIdTable(db),
                                    referencedColumn:
                                        $$TaskRecurrenceRulesTableReferences
                                            ._parentTaskIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskOccurrencesRefs)
                        await $_getPrefetchedData<
                          TaskRecurrenceRuleRow,
                          $TaskRecurrenceRulesTable,
                          TaskOccurrenceRow
                        >(
                          currentTable: table,
                          referencedTable: $$TaskRecurrenceRulesTableReferences
                              ._taskOccurrencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TaskRecurrenceRulesTableReferences(
                                db,
                                table,
                                p0,
                              ).taskOccurrencesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ruleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TaskRecurrenceRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$SystumDatabase,
      $TaskRecurrenceRulesTable,
      TaskRecurrenceRuleRow,
      $$TaskRecurrenceRulesTableFilterComposer,
      $$TaskRecurrenceRulesTableOrderingComposer,
      $$TaskRecurrenceRulesTableAnnotationComposer,
      $$TaskRecurrenceRulesTableCreateCompanionBuilder,
      $$TaskRecurrenceRulesTableUpdateCompanionBuilder,
      (TaskRecurrenceRuleRow, $$TaskRecurrenceRulesTableReferences),
      TaskRecurrenceRuleRow,
      PrefetchHooks Function({bool parentTaskId, bool taskOccurrencesRefs})
    >;
typedef $$TaskOccurrencesTableCreateCompanionBuilder =
    TaskOccurrencesCompanion Function({
      required String id,
      Value<String?> ruleId,
      required int occurrenceDate,
      Value<int?> dueDate,
      Value<int?> dueTime,
      Value<String?> dueTimezone,
      Value<bool> completed,
      Value<bool> isDeleted,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TaskOccurrencesTableUpdateCompanionBuilder =
    TaskOccurrencesCompanion Function({
      Value<String> id,
      Value<String?> ruleId,
      Value<int> occurrenceDate,
      Value<int?> dueDate,
      Value<int?> dueTime,
      Value<String?> dueTimezone,
      Value<bool> completed,
      Value<bool> isDeleted,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$TaskOccurrencesTableReferences
    extends
        BaseReferences<
          _$SystumDatabase,
          $TaskOccurrencesTable,
          TaskOccurrenceRow
        > {
  $$TaskOccurrencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TaskRecurrenceRulesTable _ruleIdTable(_$SystumDatabase db) => db
      .taskRecurrenceRules
      .createAlias('task_occurrences__rule_id__task_recurrence_rules__id');

  $$TaskRecurrenceRulesTableProcessedTableManager? get ruleId {
    final $_column = $_itemColumn<String>('rule_id');
    if ($_column == null) return null;
    final manager = $$TaskRecurrenceRulesTableTableManager(
      $_db,
      $_db.taskRecurrenceRules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ruleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskOccurrencesTableFilterComposer
    extends Composer<_$SystumDatabase, $TaskOccurrencesTable> {
  $$TaskOccurrencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueTime => $composableBuilder(
    column: $table.dueTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueTimezone => $composableBuilder(
    column: $table.dueTimezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TaskRecurrenceRulesTableFilterComposer get ruleId {
    final $$TaskRecurrenceRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.taskRecurrenceRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRecurrenceRulesTableFilterComposer(
            $db: $db,
            $table: $db.taskRecurrenceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskOccurrencesTableOrderingComposer
    extends Composer<_$SystumDatabase, $TaskOccurrencesTable> {
  $$TaskOccurrencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueTime => $composableBuilder(
    column: $table.dueTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueTimezone => $composableBuilder(
    column: $table.dueTimezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TaskRecurrenceRulesTableOrderingComposer get ruleId {
    final $$TaskRecurrenceRulesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.ruleId,
          referencedTable: $db.taskRecurrenceRules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TaskRecurrenceRulesTableOrderingComposer(
                $db: $db,
                $table: $db.taskRecurrenceRules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TaskOccurrencesTableAnnotationComposer
    extends Composer<_$SystumDatabase, $TaskOccurrencesTable> {
  $$TaskOccurrencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get dueTime =>
      $composableBuilder(column: $table.dueTime, builder: (column) => column);

  GeneratedColumn<String> get dueTimezone => $composableBuilder(
    column: $table.dueTimezone,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TaskRecurrenceRulesTableAnnotationComposer get ruleId {
    final $$TaskRecurrenceRulesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.ruleId,
          referencedTable: $db.taskRecurrenceRules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TaskRecurrenceRulesTableAnnotationComposer(
                $db: $db,
                $table: $db.taskRecurrenceRules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TaskOccurrencesTableTableManager
    extends
        RootTableManager<
          _$SystumDatabase,
          $TaskOccurrencesTable,
          TaskOccurrenceRow,
          $$TaskOccurrencesTableFilterComposer,
          $$TaskOccurrencesTableOrderingComposer,
          $$TaskOccurrencesTableAnnotationComposer,
          $$TaskOccurrencesTableCreateCompanionBuilder,
          $$TaskOccurrencesTableUpdateCompanionBuilder,
          (TaskOccurrenceRow, $$TaskOccurrencesTableReferences),
          TaskOccurrenceRow,
          PrefetchHooks Function({bool ruleId})
        > {
  $$TaskOccurrencesTableTableManager(
    _$SystumDatabase db,
    $TaskOccurrencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskOccurrencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskOccurrencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskOccurrencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> ruleId = const Value.absent(),
                Value<int> occurrenceDate = const Value.absent(),
                Value<int?> dueDate = const Value.absent(),
                Value<int?> dueTime = const Value.absent(),
                Value<String?> dueTimezone = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskOccurrencesCompanion(
                id: id,
                ruleId: ruleId,
                occurrenceDate: occurrenceDate,
                dueDate: dueDate,
                dueTime: dueTime,
                dueTimezone: dueTimezone,
                completed: completed,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> ruleId = const Value.absent(),
                required int occurrenceDate,
                Value<int?> dueDate = const Value.absent(),
                Value<int?> dueTime = const Value.absent(),
                Value<String?> dueTimezone = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TaskOccurrencesCompanion.insert(
                id: id,
                ruleId: ruleId,
                occurrenceDate: occurrenceDate,
                dueDate: dueDate,
                dueTime: dueTime,
                dueTimezone: dueTimezone,
                completed: completed,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskOccurrencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ruleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (ruleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ruleId,
                                referencedTable:
                                    $$TaskOccurrencesTableReferences
                                        ._ruleIdTable(db),
                                referencedColumn:
                                    $$TaskOccurrencesTableReferences
                                        ._ruleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TaskOccurrencesTableProcessedTableManager =
    ProcessedTableManager<
      _$SystumDatabase,
      $TaskOccurrencesTable,
      TaskOccurrenceRow,
      $$TaskOccurrencesTableFilterComposer,
      $$TaskOccurrencesTableOrderingComposer,
      $$TaskOccurrencesTableAnnotationComposer,
      $$TaskOccurrencesTableCreateCompanionBuilder,
      $$TaskOccurrencesTableUpdateCompanionBuilder,
      (TaskOccurrenceRow, $$TaskOccurrencesTableReferences),
      TaskOccurrenceRow,
      PrefetchHooks Function({bool ruleId})
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      required String id,
      required String taskId,
      required String scheduleType,
      Value<String?> timezoneId,
      Value<int?> scheduledAtUtcMs,
      Value<int?> localTimeSeconds,
      Value<int> interval,
      Value<int?> weekdays,
      Value<int?> startDate,
      Value<int?> endDate,
      Value<int?> maxOccurrences,
      Value<String> status,
      Value<String?> cancellationReason,
      Value<int?> cancelledAtMs,
      required int createdAtMs,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> scheduleType,
      Value<String?> timezoneId,
      Value<int?> scheduledAtUtcMs,
      Value<int?> localTimeSeconds,
      Value<int> interval,
      Value<int?> weekdays,
      Value<int?> startDate,
      Value<int?> endDate,
      Value<int?> maxOccurrences,
      Value<String> status,
      Value<String?> cancellationReason,
      Value<int?> cancelledAtMs,
      Value<int> createdAtMs,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

final class $$RemindersTableReferences
    extends BaseReferences<_$SystumDatabase, $RemindersTable, ReminderRow> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$SystumDatabase db) =>
      db.tasks.createAlias('reminders__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$SystumDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledAtUtcMs => $composableBuilder(
    column: $table.scheduledAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localTimeSeconds => $composableBuilder(
    column: $table.localTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxOccurrences => $composableBuilder(
    column: $table.maxOccurrences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cancellationReason => $composableBuilder(
    column: $table.cancellationReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cancelledAtMs => $composableBuilder(
    column: $table.cancelledAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$SystumDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledAtUtcMs => $composableBuilder(
    column: $table.scheduledAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localTimeSeconds => $composableBuilder(
    column: $table.localTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxOccurrences => $composableBuilder(
    column: $table.maxOccurrences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cancellationReason => $composableBuilder(
    column: $table.cancellationReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cancelledAtMs => $composableBuilder(
    column: $table.cancelledAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$SystumDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduledAtUtcMs => $composableBuilder(
    column: $table.scheduledAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localTimeSeconds => $composableBuilder(
    column: $table.localTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<int> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<int> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<int> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get maxOccurrences => $composableBuilder(
    column: $table.maxOccurrences,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get cancellationReason => $composableBuilder(
    column: $table.cancellationReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cancelledAtMs => $composableBuilder(
    column: $table.cancelledAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$SystumDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (ReminderRow, $$RemindersTableReferences),
          ReminderRow,
          PrefetchHooks Function({bool taskId})
        > {
  $$RemindersTableTableManager(_$SystumDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> scheduleType = const Value.absent(),
                Value<String?> timezoneId = const Value.absent(),
                Value<int?> scheduledAtUtcMs = const Value.absent(),
                Value<int?> localTimeSeconds = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<int?> weekdays = const Value.absent(),
                Value<int?> startDate = const Value.absent(),
                Value<int?> endDate = const Value.absent(),
                Value<int?> maxOccurrences = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> cancellationReason = const Value.absent(),
                Value<int?> cancelledAtMs = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                taskId: taskId,
                scheduleType: scheduleType,
                timezoneId: timezoneId,
                scheduledAtUtcMs: scheduledAtUtcMs,
                localTimeSeconds: localTimeSeconds,
                interval: interval,
                weekdays: weekdays,
                startDate: startDate,
                endDate: endDate,
                maxOccurrences: maxOccurrences,
                status: status,
                cancellationReason: cancellationReason,
                cancelledAtMs: cancelledAtMs,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String scheduleType,
                Value<String?> timezoneId = const Value.absent(),
                Value<int?> scheduledAtUtcMs = const Value.absent(),
                Value<int?> localTimeSeconds = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<int?> weekdays = const Value.absent(),
                Value<int?> startDate = const Value.absent(),
                Value<int?> endDate = const Value.absent(),
                Value<int?> maxOccurrences = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> cancellationReason = const Value.absent(),
                Value<int?> cancelledAtMs = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                taskId: taskId,
                scheduleType: scheduleType,
                timezoneId: timezoneId,
                scheduledAtUtcMs: scheduledAtUtcMs,
                localTimeSeconds: localTimeSeconds,
                interval: interval,
                weekdays: weekdays,
                startDate: startDate,
                endDate: endDate,
                maxOccurrences: maxOccurrences,
                status: status,
                cancellationReason: cancellationReason,
                cancelledAtMs: cancelledAtMs,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$RemindersTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$RemindersTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$SystumDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (ReminderRow, $$RemindersTableReferences),
      ReminderRow,
      PrefetchHooks Function({bool taskId})
    >;

class $SystumDatabaseManager {
  final _$SystumDatabase _db;
  $SystumDatabaseManager(this._db);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db, _db.focusSessions);
  $$FocusSessionIntervalsTableTableManager get focusSessionIntervals =>
      $$FocusSessionIntervalsTableTableManager(_db, _db.focusSessionIntervals);
  $$TaskRecurrenceRulesTableTableManager get taskRecurrenceRules =>
      $$TaskRecurrenceRulesTableTableManager(_db, _db.taskRecurrenceRules);
  $$TaskOccurrencesTableTableManager get taskOccurrences =>
      $$TaskOccurrencesTableTableManager(_db, _db.taskOccurrences);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
}
