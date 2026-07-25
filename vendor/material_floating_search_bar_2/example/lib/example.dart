import 'package:flutter/material.dart';
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';

class Example extends StatefulWidget {
  const Example({super.key});

  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // This is handled by the search bar itself.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // buildMap(),
          // buildBottomNavigationBar(),
          buildFloatingSearchBar(),
        ],
      ),
    );
  }

  Widget buildFloatingSearchBar() {
    final bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return FloatingSearchBar(
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 800),
      transitionCurve: Curves.easeInOut,
      physics: const BouncingScrollPhysics(),
      axisAlignment: isPortrait ? 0.0 : -1.0,
      openAxisAlignment: 0.0,
      width: isPortrait ? 600 : 500,
      debounceDelay: const Duration(milliseconds: 500),
      onQueryChanged: (String query) {
        // Call your model, bloc, controller here.
      },
      // Specify a custom transition to be used for
      // animating between opened and closed stated.
      transition: CircularFloatingSearchBarTransition(),
      actions: <Widget>[
        FloatingSearchBarAction(
          child: CircularButton(
            icon: const Icon(Icons.place),
            onPressed: () {},
          ),
        ),
        FloatingSearchBarAction.searchToClear(
          showIfClosed: false,
        ),
      ],
      builder: (BuildContext context, Animation<double> transition) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.white,
            elevation: 4.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: Colors.accents.map((MaterialAccentColor color) {
                return Container(height: 112, color: color);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

/* class ScrollingExample extends StatelessWidget {
  const ScrollingExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ignore: missing_required_param
    return FloatingSearchBar(
      // Your pages or just a simple Scaffold...
      body: IndexedStack(
        children: [
          MyAwesomePage(),
        ],
      ),
    );
  }
} */

class MyAwesomePage extends StatelessWidget {
  const MyAwesomePage({super.key});

  @override
  Widget build(BuildContext context) {
    /// Wrap you Scrollable in a FloatingSearchBarScrollNotifier
    /// to indicate that the FloatingSearchBar should react to
    /// scroll events from this Scrollable.
    return FloatingSearchBarScrollNotifier(
      child: SingleChildScrollView(
        child: Container(
          height: 500,
        ),
      ),
    );
  }
}
