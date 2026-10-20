//! Entrada por gamepad: traduz botões e analógicos em ações do launcher.
//!
//! Tudo aqui é puro (o tempo entra como parâmetro), então dá para testar
//! sem controle conectado. Quem lê o hardware só alimenta o [`InputMapper`].

use serde::{Deserialize, Serialize};

const REPEAT_DELAY_MS: u64 = 400;
const REPEAT_INTERVAL_MS: u64 = 120;
/// O analógico "aperta" ao passar de PRESS e só "solta" ao voltar a RELEASE;
/// a folga entre os dois evita disparos por tremida perto do limite.
const STICK_PRESS: f32 = 0.6;
const STICK_RELEASE: f32 = 0.3;
/// Fabricante da Nintendo (Pro Controller, Joy-Con).
const NINTENDO_VENDOR_ID: u16 = 0x057e;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GamepadAction {
    Up,
    Down,
    Left,
    Right,
    Confirm,
    Back,
    Search,
    /// Botão X (à esquerda no Xbox, em cima no Nintendo): ação secundária
    /// do item focado, como mover um favorito.
    Secondary,
    QuickControls,
    TabPrevious,
    TabNext,
    Close,
}

impl GamepadAction {
    pub fn is_direction(self) -> bool {
        matches!(self, Self::Up | Self::Down | Self::Left | Self::Right)
    }
}

/// Botões em posição (como no layout do Xbox): South é o A, East o B.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PadButton {
    South,
    East,
    North,
    West,
    DPadUp,
    DPadDown,
    DPadLeft,
    DPadRight,
    Start,
    Select,
    Mode,
    LeftBumper,
    RightBumper,
    Other,
}

/// Valores de -1.0 a 1.0; no eixo Y, positivo é para cima.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StickAxis {
    LeftX,
    LeftY,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PadEvent {
    ButtonPressed(PadButton),
    ButtonReleased(PadButton),
    AxisMoved(StickAxis, f32),
    /// Um controle saiu: nenhum "soltar" vai chegar, então o estado é zerado.
    Disconnected,
}

/// Como os botões de ação são nomeados no controle. O launcher pensa em
/// posição (South é o de baixo); no layout Nintendo o A fica à direita e o
/// B embaixo, o contrário do Xbox, então confirmar e voltar trocam de lugar.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ButtonLayout {
    Xbox,
    Nintendo,
}

/// Escolha do usuário: seguir o controle conectado ou forçar um layout.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ButtonLayoutSetting {
    #[default]
    Auto,
    Xbox,
    Nintendo,
}

impl ButtonLayoutSetting {
    /// Layout efetivo para um controle de fabricante `vendor` (se conhecido).
    pub fn resolve(self, vendor: Option<u16>) -> ButtonLayout {
        match self {
            Self::Auto => layout_for_vendor(vendor),
            Self::Xbox => ButtonLayout::Xbox,
            Self::Nintendo => ButtonLayout::Nintendo,
        }
    }
}

pub fn layout_for_vendor(vendor: Option<u16>) -> ButtonLayout {
    if vendor == Some(NINTENDO_VENDOR_ID) {
        ButtonLayout::Nintendo
    } else {
        ButtonLayout::Xbox
    }
}

/// Ação de um botão no layout dado. O direcional, os gatilhos e os botões de
/// sistema são iguais em todos os layouts.
pub fn action_for_button_with(layout: ButtonLayout, button: PadButton) -> Option<GamepadAction> {
    let position = match (layout, button) {
        (ButtonLayout::Nintendo, PadButton::South) => PadButton::East,
        (ButtonLayout::Nintendo, PadButton::East) => PadButton::South,
        (ButtonLayout::Nintendo, PadButton::West) => PadButton::North,
        (ButtonLayout::Nintendo, PadButton::North) => PadButton::West,
        (_, other) => other,
    };
    action_for_button(position)
}

pub fn action_for_button(button: PadButton) -> Option<GamepadAction> {
    use GamepadAction as A;
    match button {
        PadButton::South => Some(A::Confirm),
        PadButton::East => Some(A::Back),
        PadButton::North => Some(A::Search),
        PadButton::West => Some(A::Secondary),
        PadButton::Start => Some(A::QuickControls),
        PadButton::LeftBumper => Some(A::TabPrevious),
        PadButton::RightBumper => Some(A::TabNext),
        PadButton::Mode => Some(A::Close),
        PadButton::DPadUp => Some(A::Up),
        PadButton::DPadDown => Some(A::Down),
        PadButton::DPadLeft => Some(A::Left),
        PadButton::DPadRight => Some(A::Right),
        PadButton::Select | PadButton::Other => None,
    }
}

#[derive(Debug, Clone, Copy)]
struct Held {
    action: GamepadAction,
    next_fire_ms: u64,
}

fn direction_for(axis: StickAxis, value: f32) -> GamepadAction {
    match (axis, value > 0.0) {
        (StickAxis::LeftX, true) => GamepadAction::Right,
        (StickAxis::LeftX, false) => GamepadAction::Left,
        (StickAxis::LeftY, true) => GamepadAction::Up,
        (StickAxis::LeftY, false) => GamepadAction::Down,
    }
}

#[derive(Debug, Default)]
pub struct InputMapper {
    held: Option<Held>,
    stick_x: Option<GamepadAction>,
    stick_y: Option<GamepadAction>,
}

impl InputMapper {
    pub fn new() -> Self {
        Self::default()
    }

    /// Ação gerada por um evento, se houver. Direções passam a repetir
    /// enquanto seguradas (veja [`InputMapper::tick`]).
    pub fn handle(&mut self, event: PadEvent, now_ms: u64) -> Option<GamepadAction> {
        self.handle_with(ButtonLayout::Xbox, event, now_ms)
    }

    /// Como [`InputMapper::handle`], com o layout de botões do controle de origem.
    pub fn handle_with(
        &mut self,
        layout: ButtonLayout,
        event: PadEvent,
        now_ms: u64,
    ) -> Option<GamepadAction> {
        match event {
            PadEvent::ButtonPressed(button) => {
                let action = action_for_button_with(layout, button)?;
                if action.is_direction() {
                    self.start_repeat(action, now_ms);
                }
                Some(action)
            }
            PadEvent::ButtonReleased(button) => {
                if let Some(action) =
                    action_for_button_with(layout, button).filter(|a| a.is_direction())
                {
                    self.stop_repeat(action, now_ms);
                }
                None
            }
            PadEvent::AxisMoved(axis, value) => self.handle_stick(axis, value, now_ms),
            PadEvent::Disconnected => {
                *self = Self::default();
                None
            }
        }
    }

    /// Repetição devida no instante `now_ms`. Chamar quando o prazo de
    /// [`InputMapper::next_deadline_ms`] chegar.
    pub fn tick(&mut self, now_ms: u64) -> Option<GamepadAction> {
        let held = self.held.as_mut()?;
        if now_ms < held.next_fire_ms {
            return None;
        }
        // próximo disparo conta a partir de agora: atraso não vira rajada
        held.next_fire_ms = now_ms + REPEAT_INTERVAL_MS;
        Some(held.action)
    }

    pub fn next_deadline_ms(&self) -> Option<u64> {
        self.held.map(|held| held.next_fire_ms)
    }

    fn start_repeat(&mut self, action: GamepadAction, now_ms: u64) {
        self.held = Some(Held {
            action,
            next_fire_ms: now_ms + REPEAT_DELAY_MS,
        });
    }

    /// Para a repetição de `action`. Se o analógico ainda aponta para alguma
    /// direção (diagonal, ou D-pad solto com o analógico ainda inclinado),
    /// é essa que passa a repetir.
    fn stop_repeat(&mut self, action: GamepadAction, now_ms: u64) {
        if self.held.is_some_and(|held| held.action == action) {
            self.held = None;
            if let Some(still_held) = self.stick_x.or(self.stick_y) {
                self.start_repeat(still_held, now_ms);
            }
        }
    }

    fn handle_stick(&mut self, axis: StickAxis, value: f32, now_ms: u64) -> Option<GamepadAction> {
        let magnitude = value.abs();
        let current = match axis {
            StickAxis::LeftX => self.stick_x,
            StickAxis::LeftY => self.stick_y,
        };
        let next = match current {
            _ if magnitude >= STICK_PRESS => Some(direction_for(axis, value)),
            // na faixa de histerese só vale continuar para o mesmo lado
            Some(held) if magnitude > STICK_RELEASE && direction_for(axis, value) == held => {
                current
            }
            _ => None,
        };
        match axis {
            StickAxis::LeftX => self.stick_x = next,
            StickAxis::LeftY => self.stick_y = next,
        }
        if next == current {
            return None;
        }
        if let Some(released) = current {
            self.stop_repeat(released, now_ms);
        }
        let pressed = next?;
        self.start_repeat(pressed, now_ms);
        Some(pressed)
    }
}
