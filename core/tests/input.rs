use launcher_core::input::{
    GamepadAction as Action, InputMapper, PadButton, PadEvent, StickAxis, action_for_button,
};

const DIRECTIONS: [Action; 4] = [Action::Up, Action::Down, Action::Left, Action::Right];

fn press(mapper: &mut InputMapper, button: PadButton, now: u64) -> Option<Action> {
    mapper.handle(PadEvent::ButtonPressed(button), now)
}

fn release(mapper: &mut InputMapper, button: PadButton, now: u64) -> Option<Action> {
    mapper.handle(PadEvent::ButtonReleased(button), now)
}

fn stick(mapper: &mut InputMapper, axis: StickAxis, value: f32, now: u64) -> Option<Action> {
    mapper.handle(PadEvent::AxisMoved(axis, value), now)
}

#[test]
fn face_and_system_buttons_have_fixed_meanings() {
    let expected = [
        (PadButton::South, Some(Action::Confirm)),
        (PadButton::East, Some(Action::Back)),
        (PadButton::North, Some(Action::Search)),
        (PadButton::Start, Some(Action::QuickControls)),
        (PadButton::LeftBumper, Some(Action::TabPrevious)),
        (PadButton::RightBumper, Some(Action::TabNext)),
        (PadButton::Mode, Some(Action::Close)),
        (PadButton::West, Some(Action::Secondary)),
        (PadButton::Select, None),
        (PadButton::Other, None),
    ];
    for (button, action) in expected {
        assert_eq!(action_for_button(button), action, "{button:?}");
    }
}

#[test]
fn dpad_buttons_are_directions() {
    assert_eq!(action_for_button(PadButton::DPadUp), Some(Action::Up));
    assert_eq!(action_for_button(PadButton::DPadDown), Some(Action::Down));
    assert_eq!(action_for_button(PadButton::DPadLeft), Some(Action::Left));
    assert_eq!(action_for_button(PadButton::DPadRight), Some(Action::Right));
}

#[test]
fn pressing_a_button_emits_its_action_once() {
    let mut mapper = InputMapper::new();

    assert_eq!(
        press(&mut mapper, PadButton::South, 0),
        Some(Action::Confirm)
    );
    assert_eq!(release(&mut mapper, PadButton::South, 50), None);
    assert_eq!(mapper.tick(2_000), None, "botões comuns não repetem");
}

#[test]
fn unmapped_buttons_do_nothing() {
    let mut mapper = InputMapper::new();

    assert_eq!(press(&mut mapper, PadButton::Select, 0), None);
}

#[test]
fn holding_a_direction_repeats_after_a_delay() {
    let mut mapper = InputMapper::new();

    assert_eq!(
        press(&mut mapper, PadButton::DPadDown, 0),
        Some(Action::Down)
    );
    assert_eq!(mapper.tick(399), None);
    assert_eq!(mapper.tick(400), Some(Action::Down));
    assert_eq!(mapper.tick(450), None);
    assert_eq!(mapper.tick(520), Some(Action::Down));
}

#[test]
fn releasing_stops_the_repeat() {
    let mut mapper = InputMapper::new();
    press(&mut mapper, PadButton::DPadLeft, 0);

    release(&mut mapper, PadButton::DPadLeft, 100);

    assert_eq!(mapper.tick(1_000), None);
    assert_eq!(mapper.next_deadline_ms(), None);
}

#[test]
fn releasing_another_direction_keeps_the_repeat() {
    let mut mapper = InputMapper::new();
    press(&mut mapper, PadButton::DPadLeft, 0);
    press(&mut mapper, PadButton::DPadDown, 10);

    release(&mut mapper, PadButton::DPadLeft, 20);

    assert_eq!(mapper.tick(410), Some(Action::Down));
}

#[test]
fn a_late_tick_does_not_burst() {
    let mut mapper = InputMapper::new();
    press(&mut mapper, PadButton::DPadDown, 0);

    assert_eq!(mapper.tick(5_000), Some(Action::Down));
    assert_eq!(mapper.tick(5_001), None);
    assert_eq!(mapper.tick(5_120), Some(Action::Down));
}

#[test]
fn next_deadline_tells_when_to_wake_up() {
    let mut mapper = InputMapper::new();
    assert_eq!(mapper.next_deadline_ms(), None);

    press(&mut mapper, PadButton::DPadUp, 1_000);

    assert_eq!(mapper.next_deadline_ms(), Some(1_400));
}

#[test]
fn stick_past_the_threshold_acts_like_a_dpad() {
    let mut mapper = InputMapper::new();

    assert_eq!(stick(&mut mapper, StickAxis::LeftX, 0.5, 0), None);
    assert_eq!(
        stick(&mut mapper, StickAxis::LeftX, 0.8, 10),
        Some(Action::Right)
    );
    assert_eq!(
        stick(&mut mapper, StickAxis::LeftX, 0.9, 20),
        None,
        "ainda segurando"
    );
    assert_eq!(mapper.tick(410), Some(Action::Right));
}

#[test]
fn stick_up_is_positive_on_the_y_axis() {
    let mut mapper = InputMapper::new();

    assert_eq!(
        stick(&mut mapper, StickAxis::LeftY, 0.9, 0),
        Some(Action::Up)
    );
    stick(&mut mapper, StickAxis::LeftY, 0.0, 10);
    assert_eq!(
        stick(&mut mapper, StickAxis::LeftY, -0.9, 20),
        Some(Action::Down)
    );
}

#[test]
fn stick_has_hysteresis_before_it_can_fire_again() {
    let mut mapper = InputMapper::new();
    stick(&mut mapper, StickAxis::LeftX, -0.9, 0);

    // abaixo do limite de pressão mas acima do de soltura: ainda é o mesmo gesto
    assert_eq!(stick(&mut mapper, StickAxis::LeftX, -0.5, 10), None);
    assert_eq!(stick(&mut mapper, StickAxis::LeftX, -0.9, 20), None);
    // soltou de verdade, então um novo gesto dispara de novo
    stick(&mut mapper, StickAxis::LeftX, 0.0, 30);
    assert_eq!(
        stick(&mut mapper, StickAxis::LeftX, -0.9, 40),
        Some(Action::Left)
    );
}

#[test]
fn flipping_the_stick_straight_across_changes_direction() {
    let mut mapper = InputMapper::new();
    stick(&mut mapper, StickAxis::LeftX, -0.9, 0);

    assert_eq!(
        stick(&mut mapper, StickAxis::LeftX, 0.9, 10),
        Some(Action::Right)
    );
}

#[test]
fn stick_returning_to_center_stops_the_repeat() {
    let mut mapper = InputMapper::new();
    stick(&mut mapper, StickAxis::LeftX, 0.9, 0);

    stick(&mut mapper, StickAxis::LeftX, 0.1, 100);

    assert_eq!(mapper.tick(1_000), None);
}

#[test]
fn small_stick_noise_is_ignored() {
    let mut mapper = InputMapper::new();

    for value in [0.05, -0.1, 0.2, -0.29] {
        assert_eq!(stick(&mut mapper, StickAxis::LeftX, value, 0), None);
        assert_eq!(stick(&mut mapper, StickAxis::LeftY, value, 0), None);
    }
}

#[test]
fn only_directions_repeat() {
    let mut mapper = InputMapper::new();

    for button in [
        PadButton::South,
        PadButton::East,
        PadButton::Start,
        PadButton::Mode,
    ] {
        press(&mut mapper, button, 0);
        assert_eq!(mapper.tick(10_000), None, "{button:?}");
    }
    assert!(DIRECTIONS.iter().all(|action| action.is_direction()));
    assert!(!Action::Confirm.is_direction());
}

#[test]
fn a_disconnect_stops_any_repeat() {
    let mut mapper = InputMapper::new();
    press(&mut mapper, PadButton::DPadDown, 0);

    assert_eq!(mapper.handle(PadEvent::Disconnected, 100), None);

    assert_eq!(mapper.tick(1_000), None);
    assert_eq!(mapper.next_deadline_ms(), None);
}

#[test]
fn a_disconnect_forgets_the_stick_position() {
    let mut mapper = InputMapper::new();
    stick(&mut mapper, StickAxis::LeftX, 0.9, 0);

    mapper.handle(PadEvent::Disconnected, 100);

    assert_eq!(
        stick(&mut mapper, StickAxis::LeftX, 0.9, 200),
        Some(Action::Right),
        "um novo gesto dispara de novo"
    );
}

#[test]
fn releasing_one_diagonal_axis_keeps_the_other_repeating() {
    let mut mapper = InputMapper::new();
    stick(&mut mapper, StickAxis::LeftX, 0.9, 0);
    stick(&mut mapper, StickAxis::LeftY, 0.9, 10);

    stick(&mut mapper, StickAxis::LeftY, 0.0, 100);

    assert_eq!(mapper.tick(499), None);
    assert_eq!(mapper.tick(500), Some(Action::Right));
}

#[test]
fn releasing_a_dpad_button_keeps_a_stick_that_still_points_the_same_way() {
    let mut mapper = InputMapper::new();
    stick(&mut mapper, StickAxis::LeftX, -0.9, 0);
    press(&mut mapper, PadButton::DPadLeft, 10);

    release(&mut mapper, PadButton::DPadLeft, 50);

    assert_eq!(mapper.tick(449), None);
    assert_eq!(mapper.tick(450), Some(Action::Left));
}

#[test]
fn flipping_the_stick_inside_the_hysteresis_band_lets_go_of_the_old_direction() {
    let mut mapper = InputMapper::new();
    stick(&mut mapper, StickAxis::LeftX, -0.7, 0);

    assert_eq!(stick(&mut mapper, StickAxis::LeftX, 0.5, 10), None);

    assert_eq!(
        mapper.tick(1_000),
        None,
        "não deve seguir repetindo para a esquerda"
    );
    assert_eq!(
        stick(&mut mapper, StickAxis::LeftX, 0.9, 1_010),
        Some(Action::Right)
    );
}

// ---------- layout dos botões (Xbox x Nintendo) ----------

mod layout {
    use super::*;
    use launcher_core::input::{
        ButtonLayout, ButtonLayoutSetting, action_for_button_with, layout_for_vendor,
    };

    const NINTENDO_VENDOR: u16 = 0x057e;
    const MICROSOFT_VENDOR: u16 = 0x045e;

    #[test]
    fn the_xbox_layout_is_the_default_one() {
        for button in [
            PadButton::South,
            PadButton::East,
            PadButton::North,
            PadButton::West,
        ] {
            assert_eq!(
                action_for_button_with(ButtonLayout::Xbox, button),
                action_for_button(button),
                "{button:?}"
            );
        }
    }

    #[test]
    fn nintendo_swaps_confirm_and_back_to_match_the_printed_labels() {
        // no Nintendo o A fica à direita (East) e o B embaixo (South)
        assert_eq!(
            action_for_button_with(ButtonLayout::Nintendo, PadButton::East),
            Some(Action::Confirm)
        );
        assert_eq!(
            action_for_button_with(ButtonLayout::Nintendo, PadButton::South),
            Some(Action::Back)
        );
    }

    #[test]
    fn nintendo_search_is_the_button_labeled_y_on_the_left() {
        assert_eq!(
            action_for_button_with(ButtonLayout::Nintendo, PadButton::West),
            Some(Action::Search)
        );
        // o X do Nintendo fica em cima: é a ação secundária (mover, por
        // exemplo), como o X do Xbox, que fica à esquerda
        assert_eq!(
            action_for_button_with(ButtonLayout::Nintendo, PadButton::North),
            Some(Action::Secondary)
        );
    }

    #[test]
    fn dpad_bumpers_and_system_buttons_do_not_depend_on_the_layout() {
        for button in [
            PadButton::DPadUp,
            PadButton::DPadDown,
            PadButton::DPadLeft,
            PadButton::DPadRight,
            PadButton::Start,
            PadButton::Select,
            PadButton::Mode,
            PadButton::LeftBumper,
            PadButton::RightBumper,
            PadButton::Other,
        ] {
            assert_eq!(
                action_for_button_with(ButtonLayout::Nintendo, button),
                action_for_button_with(ButtonLayout::Xbox, button),
                "{button:?}"
            );
        }
    }

    #[test]
    fn nintendo_controllers_are_recognized_by_vendor() {
        assert_eq!(
            layout_for_vendor(Some(NINTENDO_VENDOR)),
            ButtonLayout::Nintendo
        );
        assert_eq!(
            layout_for_vendor(Some(MICROSOFT_VENDOR)),
            ButtonLayout::Xbox
        );
        assert_eq!(layout_for_vendor(None), ButtonLayout::Xbox);
    }

    #[test]
    fn automatic_follows_the_device_and_manual_choices_win() {
        let nintendo_pad = Some(NINTENDO_VENDOR);
        let xbox_pad = Some(MICROSOFT_VENDOR);

        assert_eq!(
            ButtonLayoutSetting::Auto.resolve(nintendo_pad),
            ButtonLayout::Nintendo
        );
        assert_eq!(
            ButtonLayoutSetting::Auto.resolve(xbox_pad),
            ButtonLayout::Xbox
        );
        assert_eq!(
            ButtonLayoutSetting::Xbox.resolve(nintendo_pad),
            ButtonLayout::Xbox
        );
        assert_eq!(
            ButtonLayoutSetting::Nintendo.resolve(xbox_pad),
            ButtonLayout::Nintendo
        );
    }

    #[test]
    fn the_mapper_applies_the_layout_it_is_given() {
        let mut mapper = InputMapper::new();

        let confirm = mapper.handle_with(
            ButtonLayout::Nintendo,
            PadEvent::ButtonPressed(PadButton::East),
            0,
        );
        let back = mapper.handle_with(
            ButtonLayout::Nintendo,
            PadEvent::ButtonPressed(PadButton::South),
            10,
        );

        assert_eq!(confirm, Some(Action::Confirm));
        assert_eq!(back, Some(Action::Back));
    }

    #[test]
    fn handle_without_a_layout_keeps_the_xbox_behavior() {
        let mut mapper = InputMapper::new();

        assert_eq!(
            press(&mut mapper, PadButton::South, 0),
            Some(Action::Confirm)
        );
    }

    #[test]
    fn directions_still_repeat_under_the_nintendo_layout() {
        let mut mapper = InputMapper::new();

        let first = mapper.handle_with(
            ButtonLayout::Nintendo,
            PadEvent::ButtonPressed(PadButton::DPadDown),
            0,
        );

        assert_eq!(first, Some(Action::Down));
        assert_eq!(mapper.tick(400), Some(Action::Down));
    }
}
