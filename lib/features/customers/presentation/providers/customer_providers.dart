import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/customer_model.dart';
import '../../data/repositories/customer_repository.dart';

final customersProvider = FutureProvider<List<CustomerModel>>((ref) async {
  return ref.read(customerRepositoryProvider).getAll();
});

final activeCustomersProvider = FutureProvider<List<CustomerModel>>((ref) async {
  return ref.read(customerRepositoryProvider).getActive();
});
