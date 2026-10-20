import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/state/favorites_order.dart';

void main() {
  const order = ['a', 'b', 'c', 'd', 'e', 'f'];

  group('moveItem', () {
    test('moves forward and backward, returning a new list', () {
      expect(moveItem(order, 0, 2), ['b', 'c', 'a', 'd', 'e', 'f']);
      expect(moveItem(order, 4, 1), ['a', 'e', 'b', 'c', 'd', 'f']);
      expect(order, ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('the target is kept inside the list', () {
      expect(moveItem(order, 5, 99), order);
      expect(moveItem(order, 0, -3), order);
    });
  });

  group('moveTarget', () {
    test('left and right step one, up and down step a row', () {
      expect(moveTarget(5, TraversalDirection.left, columns: 4, length: 9), 4);
      expect(moveTarget(5, TraversalDirection.right, columns: 4, length: 9), 6);
      expect(moveTarget(5, TraversalDirection.up, columns: 4, length: 9), 1);
      expect(moveTarget(1, TraversalDirection.down, columns: 4, length: 9), 5);
    });

    test('the ends of the list hold the item in place', () {
      expect(moveTarget(0, TraversalDirection.left, columns: 4, length: 3), 0);
      expect(moveTarget(2, TraversalDirection.right, columns: 4, length: 3), 2);
      expect(moveTarget(1, TraversalDirection.up, columns: 4, length: 9), 1);
      expect(moveTarget(6, TraversalDirection.down, columns: 4, length: 9), 8);
    });
  });
}
