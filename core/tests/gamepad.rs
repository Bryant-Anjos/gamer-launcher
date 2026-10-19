use launcher_core::gamepad::{pad_button_from, spawn_listener, stick_axis_from};
use launcher_core::input::{PadButton, StickAxis};
use std::ops::ControlFlow;
use std::time::{Duration, Instant};

#[test]
fn physical_buttons_map_to_positional_ones() {
    use gilrs::Button as B;
    let expected = [
        (B::South, PadButton::South),
        (B::East, PadButton::East),
        (B::North, PadButton::North),
        (B::West, PadButton::West),
        (B::DPadUp, PadButton::DPadUp),
        (B::DPadDown, PadButton::DPadDown),
        (B::DPadLeft, PadButton::DPadLeft),
        (B::DPadRight, PadButton::DPadRight),
        (B::Start, PadButton::Start),
        (B::Select, PadButton::Select),
        (B::Mode, PadButton::Mode),
        (B::LeftTrigger, PadButton::LeftBumper),
        (B::RightTrigger, PadButton::RightBumper),
        (B::C, PadButton::Other),
        (B::Unknown, PadButton::Other),
    ];
    for (physical, positional) in expected {
        assert_eq!(pad_button_from(physical), positional, "{physical:?}");
    }
}

#[test]
fn left_stick_and_dpad_axes_drive_navigation() {
    use gilrs::Axis as A;

    assert_eq!(stick_axis_from(A::LeftStickX), Some(StickAxis::LeftX));
    assert_eq!(stick_axis_from(A::LeftStickY), Some(StickAxis::LeftY));
    assert_eq!(stick_axis_from(A::DPadX), Some(StickAxis::LeftX));
    assert_eq!(stick_axis_from(A::DPadY), Some(StickAxis::LeftY));
    assert_eq!(stick_axis_from(A::RightStickX), None);
    assert_eq!(stick_axis_from(A::LeftZ), None);
}

#[test]
fn the_listener_starts_and_stops_without_a_gamepad() {
    let handle = spawn_listener(|_| ControlFlow::Continue(())).expect("udev disponível");

    let started = Instant::now();
    drop(handle);

    assert!(
        started.elapsed() < Duration::from_secs(2),
        "parar não pode travar"
    );
}
