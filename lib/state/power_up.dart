import 'package:flutter/material.dart';

/// The three power-ups a player can hold. Counts live in
/// [PreferencesService] (see `powerUpCount`) so they persist across rounds.
enum PowerUpType {
  shuffle(
    label: 'Shuffle',
    description: 'Mixes up every number on the board.',
    icon: Icons.shuffle_rounded,
  ),
  hint(
    label: 'Hint',
    description: 'Flashes one matching pair on the board.',
    icon: Icons.lightbulb_outline_rounded,
  ),
  clearRow(
    label: 'Clear Row',
    description: 'Instantly clears the bottom row.',
    icon: Icons.delete_sweep_rounded,
  );

  const PowerUpType({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;
}

/// Every [levelsPerPowerUpReward]th level the player reaches earns one
/// power-up of their choice.
const int levelsPerPowerUpReward = 10;

/// Power-ups every player owns of each type before earning any.
const int startingPowerUpCount = 1;
