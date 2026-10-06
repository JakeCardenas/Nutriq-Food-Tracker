/// Sample meals for demo mode. Values are typical reference values for the
/// listed portions — approximations, not measurements of anyone's photo.
library;

typedef SampleFood = ({
  String name,
  String serving,
  double servings,
  double kcal,
  double protein,
  double carbs,
  double fat,
});

typedef SampleMeal = ({String name, List<SampleFood> foods});

SampleFood _f(
  String name,
  String serving,
  double kcal,
  double protein,
  double carbs,
  double fat, {
  double servings = 1,
}) =>
    (name: name, serving: serving, servings: servings, kcal: kcal, protein: protein, carbs: carbs, fat: fat);

final List<SampleMeal> demoSampleMeals = [
  (
    name: 'Grilled chicken rice bowl',
    foods: [
      _f('Grilled chicken breast', '120 g', 198, 37, 0, 4.3),
      _f('Brown rice', '1 cup cooked (195 g)', 218, 4.5, 45.8, 1.6),
      _f('Steamed broccoli', '1 cup (90 g)', 31, 2.5, 6, 0.3),
      _f('Olive oil drizzle', '1 tsp (5 ml)', 40, 0, 0, 4.5),
    ],
  ),
  (
    name: 'Salmon with roasted potatoes',
    foods: [
      _f('Baked salmon fillet', '140 g', 290, 31, 0, 18),
      _f('Roasted potatoes', '1 cup (150 g)', 165, 3.5, 27, 5),
      _f('Green salad with vinaigrette', '1 side bowl', 90, 1.5, 6, 7),
    ],
  ),
  (
    name: 'Eggs and avocado toast',
    foods: [
      _f('Scrambled eggs', '2 large eggs', 182, 12.2, 2, 13.4),
      _f('Whole-wheat toast', '1 slice', 82, 4, 13.8, 1.1),
      _f('Avocado', '½ medium (68 g)', 114, 1.4, 6, 10.5),
    ],
  ),
  (
    name: 'Oatmeal with banana',
    foods: [
      _f('Oatmeal', '1 cup cooked', 166, 5.9, 28, 3.6),
      _f('Banana', '1 medium', 105, 1.3, 27, 0.4),
      _f('Peanut butter', '1 tbsp (16 g)', 95, 3.6, 3.6, 8.2),
    ],
  ),
  (
    name: 'Spaghetti with tomato sauce',
    foods: [
      _f('Spaghetti', '1½ cups cooked', 330, 12, 64.5, 2),
      _f('Marinara sauce', '½ cup', 70, 2, 10, 2.5),
      _f('Grated parmesan', '1 tbsp', 22, 1.9, 0.2, 1.4),
    ],
  ),
  (
    name: 'Greek yogurt parfait',
    foods: [
      _f('Greek yogurt (2%)', '170 g', 146, 20, 7.6, 3.8),
      _f('Granola', '¼ cup (30 g)', 130, 3, 20, 4.5),
      _f('Mixed berries', '½ cup', 35, 0.5, 8.5, 0.2),
    ],
  ),
  (
    name: 'Tofu vegetable stir-fry',
    foods: [
      _f('Firm tofu', '150 g', 215, 23, 4.2, 13),
      _f('Stir-fried vegetables', '1½ cups', 110, 4, 15, 4.5),
      _f('Jasmine rice', '1 cup cooked', 205, 4.3, 45, 0.4),
    ],
  ),
  (
    name: 'Chicken tacos',
    foods: [
      _f('Chicken taco, corn tortilla', '1 taco', 170, 12, 15, 6.5, servings: 2),
      _f('Black beans', '½ cup', 114, 7.6, 20, 0.5),
      _f('Pico de gallo', '¼ cup', 10, 0.4, 2.3, 0),
    ],
  ),
];
