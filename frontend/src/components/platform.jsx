import { StatusBadge } from "./ui";
import { ACCESS, SUBSCRIPTION } from "../lib/platform";

// Badges for the two separate store states (text + colour + icon, never colour alone).

export const AccessBadge = ({ status }) => <StatusBadge status={ACCESS[status]?.badge ?? status} label={ACCESS[status]?.label ?? status} />;

export const SubscriptionBadge = ({ state }) => <StatusBadge status={SUBSCRIPTION[state]?.badge ?? state} label={SUBSCRIPTION[state]?.label ?? state} />;
