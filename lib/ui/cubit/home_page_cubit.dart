import 'package:flutter_bloc/flutter_bloc.dart';

class HomePageCubit extends Cubit<int> {
  HomePageCubit() : super(0);

  void changeIndex(int index) {
    emit(index);
  }
}
