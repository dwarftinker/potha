import 'package:flutter_test/flutter_test.dart';
import 'package:potha/features/library/domain/text_fold.dart';

void main() {
  group('fold', () {
    test('ignores case and accents', () {
      expect(fold('Tolstoy'), 'tolstoy');
      expect(fold('TOLSTÓY'), 'tolstoy');
    });

    test('folds Latin-1 and Latin Extended letters', () {
      expect(fold('é'), 'e');
      expect(fold('ß'), 'ss');
      expect(fold('Ø'), 'o');
      expect(fold('Ł'), 'l');
      expect(fold('Œuvre'), 'oeuvre');
      expect(fold('Ærøskøbing'), 'aeroskobing');
      expect(fold('Dvořák'), 'dvorak');
      expect(fold('Şişli'), 'sisli');
    });

    test('passes non-Latin scripts through, lower-cased', () {
      expect(fold('Преступление'), 'преступление');
      expect(fold('ශ්‍රී ලංකා'), 'ශ්‍රී ලංකා');
    });
  });

  group('sortTitle', () {
    test('drops a leading article', () {
      expect(sortTitle('The Idiot'), 'idiot');
      expect(sortTitle('A Tale'), 'tale');
      expect(sortTitle('An Essay'), 'essay');
    });

    test('keeps words that only start like an article', () {
      expect(sortTitle('Theory'), 'theory');
      expect(sortTitle('Anna Karenina'), 'anna karenina');
    });

    test('folds case and accents', () {
      expect(sortTitle('Ébauche'), 'ebauche');
    });

    test('keeps a title that is only an article', () {
      expect(sortTitle('The'), 'the');
    });
  });

  test('searchKey folds title and author joined by a space', () {
    expect(searchKey('Anna Karenina', 'Lev Tolstóy'), 'anna karenina lev tolstoy');
    expect(searchKey('Anna Karenina', null), 'anna karenina');
  });
}
