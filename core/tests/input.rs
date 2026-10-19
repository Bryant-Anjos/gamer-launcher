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
        (PadButton::West, None),
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

    assert_eq!(press(&mut mapper, PadButton::West, 0), None);
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
