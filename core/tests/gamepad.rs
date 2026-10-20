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

#[test]
fn the_listener_reports_how_many_gamepads_are_connected() {
    let handle = spawn_listener(|_| ControlFlow::Continue(())).expect("udev disponível");

    // sem garantir hardware, só dá para checar que a leitura existe e é coerente
    let connected = handle.connected_gamepads();

    assert!(connected < 64, "contagem absurda: {connected}");
}

mod layout {
    use super::*;
    use launcher_core::gamepad::{SharedLayout, spawn_listener_with};
    use launcher_core::input::ButtonLayoutSetting;

    const ALL: [ButtonLayoutSetting; 3] = [
        ButtonLayoutSetting::Auto,
        ButtonLayoutSetting::Xbox,
        ButtonLayoutSetting::Nintendo,
    ];

    #[test]
    fn the_shared_setting_keeps_whatever_was_stored() {
        for stored in ALL {
            let shared = SharedLayout::new(ButtonLayoutSetting::Auto);

            shared.set(stored);

            assert_eq!(shared.get(), stored);
        }
    }

    #[test]
    fn a_new_shared_setting_starts_with_the_given_value() {
        for initial in ALL {
            assert_eq!(SharedLayout::new(initial).get(), initial);
        }
    }

    #[test]
    fn the_running_listener_takes_layout_changes() {
        let handle =
            spawn_listener_with(ButtonLayoutSetting::Nintendo, |_| ControlFlow::Continue(()))
                .expect("udev disponível");
        assert_eq!(handle.layout_setting(), ButtonLayoutSetting::Nintendo);

        handle.set_layout_setting(ButtonLayoutSetting::Xbox);

        assert_eq!(handle.layout_setting(), ButtonLayoutSetting::Xbox);
    }

    #[test]
    fn the_default_listener_follows_the_connected_controller() {
        let handle = spawn_listener(|_| ControlFlow::Continue(())).expect("udev disponível");

        assert_eq!(handle.layout_setting(), ButtonLayoutSetting::Auto);
    }
}

mod last_vendor {
    use super::*;
    use launcher_core::gamepad::LastVendor;
    use launcher_core::input::ButtonLayout;

    const NINTENDO: u16 = 0x057e;
    const MICROSOFT: u16 = 0x045e;

    #[test]
    fn starts_unknown_and_looks_like_xbox() {
        let last = LastVendor::default();

        assert_eq!(last.get(), None);
        assert_eq!(last.detected_layout(), ButtonLayout::Xbox);
    }

    #[test]
    fn a_nintendo_controller_is_detected_as_nintendo() {
        let last = LastVendor::default();

        last.set(Some(NINTENDO));

        assert_eq!(last.get(), Some(NINTENDO));
        assert_eq!(last.detected_layout(), ButtonLayout::Nintendo);
    }

    #[test]
    fn the_last_controller_used_wins() {
        let last = LastVendor::default();
        last.set(Some(NINTENDO));

        last.set(Some(MICROSOFT));

        assert_eq!(last.detected_layout(), ButtonLayout::Xbox);
    }

    #[test]
    fn a_controller_without_vendor_keeps_the_previous_one() {
        let last = LastVendor::default();
        last.set(Some(NINTENDO));

        last.set(None);

        assert_eq!(last.get(), Some(NINTENDO));
    }

    #[test]
    fn the_listener_reports_a_detected_layout() {
        let handle = spawn_listener(|_| ControlFlow::Continue(())).expect("udev disponível");

        // sem hardware garantido, só a coerência: algum dos dois layouts
        let detected = handle.detected_layout();

        assert!(matches!(
            detected,
            ButtonLayout::Xbox | ButtonLayout::Nintendo
        ));
    }
}
