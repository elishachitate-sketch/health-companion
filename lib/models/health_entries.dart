import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

abstract interface class TimestampedHealthEntry {
  String get id;
  DateTime get timestamp;
  String get distributionKey;
}

String formatHealthEntryTimestamp(DateTime timestamp) =>
    DateFormat('dd/MM/yyyy, hh:mm a').format(timestamp.toLocal());

class MoodEntry extends HiveObject implements TimestampedHealthEntry {
  MoodEntry({
    required this.id,
    required this.mood,
    required this.timestamp,
    this.note = '',
  }) {
    if (!const {'happy', 'neutral', 'worried', 'tired'}.contains(mood)) {
      throw ArgumentError.value(mood, 'mood', 'Unsupported mood');
    }
  }

  @override
  final String id;
  final String mood;
  @override
  final DateTime timestamp;
  final String note;

  @override
  String get distributionKey => mood;
}

class MoodEntryAdapter extends TypeAdapter<MoodEntry> {
  @override
  final int typeId = 30;

  @override
  MoodEntry read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, length = reader.readByte(); index < length; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return MoodEntry(
      id: fields[0] as String,
      mood: fields[1] as String,
      timestamp: fields[2] as DateTime,
      note: fields[3] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, MoodEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mood)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.note);
  }
}

class DailyFunctionEntry extends HiveObject implements TimestampedHealthEntry {
  DailyFunctionEntry({
    required this.id,
    required this.category,
    required this.value,
    required this.timestamp,
  }) {
    if (!const {'eating', 'walking', 'sleep', 'social'}.contains(category)) {
      throw ArgumentError.value(category, 'category', 'Unsupported category');
    }
    if (value < 0 || value > 5) {
      throw RangeError.range(value, 0, 5, 'value');
    }
  }

  @override
  final String id;
  final String category;
  final int value;
  @override
  final DateTime timestamp;

  @override
  String get distributionKey => category;
}

class DailyFunctionEntryAdapter extends TypeAdapter<DailyFunctionEntry> {
  @override
  final int typeId = 31;

  @override
  DailyFunctionEntry read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, length = reader.readByte(); index < length; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return DailyFunctionEntry(
      id: fields[0] as String,
      category: fields[1] as String,
      value: fields[2] as int,
      timestamp: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DailyFunctionEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.value)
      ..writeByte(3)
      ..write(obj.timestamp);
  }
}

class CognitiveEntry extends HiveObject implements TimestampedHealthEntry {
  CognitiveEntry({
    required this.id,
    required this.score,
    required this.totalQuestions,
    required this.timestamp,
  }) {
    if (score < 0 || score > 100) {
      throw RangeError.range(score, 0, 100, 'score');
    }
    if (totalQuestions <= 0) {
      throw RangeError.range(totalQuestions, 1, null, 'totalQuestions');
    }
  }

  @override
  final String id;
  final int score;
  final int totalQuestions;
  @override
  final DateTime timestamp;

  @override
  String get distributionKey {
    final lower = (score ~/ 10) * 10;
    final upper = lower == 100 ? 100 : lower + 9;
    return '$lower-$upper';
  }
}

class CognitiveEntryAdapter extends TypeAdapter<CognitiveEntry> {
  @override
  final int typeId = 32;

  @override
  CognitiveEntry read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, length = reader.readByte(); index < length; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return CognitiveEntry(
      id: fields[0] as String,
      score: fields[1] as int,
      totalQuestions: fields[2] as int,
      timestamp: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CognitiveEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.score)
      ..writeByte(2)
      ..write(obj.totalQuestions)
      ..writeByte(3)
      ..write(obj.timestamp);
  }
}

class LifestyleEntry extends HiveObject implements TimestampedHealthEntry {
  LifestyleEntry({
    required this.id,
    required this.action,
    required this.timestamp,
  }) {
    if (!const {'water', 'exercise', 'rest', 'prayer', 'meals'}
        .contains(action)) {
      throw ArgumentError.value(action, 'action', 'Unsupported action');
    }
  }

  @override
  final String id;
  final String action;
  @override
  final DateTime timestamp;

  @override
  String get distributionKey => action;
}

class LifestyleEntryAdapter extends TypeAdapter<LifestyleEntry> {
  @override
  final int typeId = 33;

  @override
  LifestyleEntry read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, length = reader.readByte(); index < length; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return LifestyleEntry(
      id: fields[0] as String,
      action: fields[1] as String,
      timestamp: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LifestyleEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.action)
      ..writeByte(2)
      ..write(obj.timestamp);
  }
}

class ChatToneEntry extends HiveObject implements TimestampedHealthEntry {
  ChatToneEntry({
    required this.id,
    required this.tone,
    required this.messageSnippet,
    required this.timestamp,
  }) {
    if (!const {'supportive', 'encouraging', 'neutral'}.contains(tone)) {
      throw ArgumentError.value(tone, 'tone', 'Unsupported chat tone');
    }
  }

  @override
  final String id;
  final String tone;
  final String messageSnippet;
  @override
  final DateTime timestamp;

  @override
  String get distributionKey => tone;
}

class ChatToneEntryAdapter extends TypeAdapter<ChatToneEntry> {
  @override
  final int typeId = 34;

  @override
  ChatToneEntry read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, length = reader.readByte(); index < length; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return ChatToneEntry(
      id: fields[0] as String,
      tone: fields[1] as String,
      messageSnippet: fields[2] as String,
      timestamp: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChatToneEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tone)
      ..writeByte(2)
      ..write(obj.messageSnippet)
      ..writeByte(3)
      ..write(obj.timestamp);
  }
}
