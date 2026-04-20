"""iCalendar (RFC 5545) read/write utilities.

We deliberately avoid an external library: the subset of iCal needed
for blocking bookings (``VCALENDAR`` → ``VEVENT`` with ``DTSTART;VALUE=DATE``
and ``DTEND;VALUE=DATE``) is tiny, and third-party parsers have
historically been a compatibility liability with Airbnb's quirky feeds.
"""

from __future__ import annotations

import re
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timezone
from typing import Iterable


# ── Line-folding helpers ────────────────────────────────
def _fold(line: str) -> str:
    """Fold a single content line to ≤75 octets per RFC 5545 §3.1."""
    if len(line) <= 75:
        return line
    out: list[str] = []
    while len(line) > 75:
        out.append(line[:75])
        line = " " + line[75:]     # leading space = continuation
    out.append(line)
    return "\r\n".join(out)


def _unfold(lines: Iterable[str]) -> list[str]:
    """Collapse RFC 5545 continuation lines back into single logical lines."""
    out: list[str] = []
    for raw in lines:
        # Handle both LF and CRLF sources; strip the trailing newline only.
        line = raw.rstrip("\r\n")
        if line.startswith(" ") or line.startswith("\t"):
            if out:
                out[-1] += line[1:]
            continue
        out.append(line)
    return out


def _esc(value: str) -> str:
    """Escape ``SUMMARY``/``DESCRIPTION`` text values."""
    return (
        value
        .replace("\\", "\\\\")
        .replace(";", "\\;")
        .replace(",", "\\,")
        .replace("\n", "\\n")
    )


def _unesc(value: str) -> str:
    """Inverse of :func:`_esc` for parsed TEXT values."""
    out: list[str] = []
    i = 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            if nxt in (",", ";", "\\"):
                out.append(nxt)
                i += 2
                continue
            if nxt in ("n", "N"):
                out.append("\n")
                i += 2
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def _fmt_date(d: date) -> str:
    return d.strftime("%Y%m%d")


def _fmt_datetime_utc(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


# ── Export: build an iCalendar feed ─────────────────────
@dataclass
class ICalEvent:
    uid: str
    start: date
    end: date                      # exclusive – iCal's ``DTEND`` for DATE values is also exclusive
    summary: str
    description: str | None = None


def build_feed(
    *,
    events: Iterable[ICalEvent],
    prod_id: str = "-//TALAA//Property Calendar//EN",
    cal_name: str | None = None,
) -> str:
    """Render a full ``VCALENDAR`` text block ready for HTTP response."""
    lines: list[str] = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        f"PRODID:{prod_id}",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
    ]
    if cal_name:
        lines.append(f"X-WR-CALNAME:{_esc(cal_name)}")

    now_stamp = _fmt_datetime_utc(datetime.now(tz=timezone.utc))
    for ev in events:
        lines += [
            "BEGIN:VEVENT",
            f"UID:{ev.uid}",
            f"DTSTAMP:{now_stamp}",
            f"DTSTART;VALUE=DATE:{_fmt_date(ev.start)}",
            f"DTEND;VALUE=DATE:{_fmt_date(ev.end)}",
            f"SUMMARY:{_esc(ev.summary)}",
        ]
        if ev.description:
            lines.append(f"DESCRIPTION:{_esc(ev.description)}")
        lines += ["STATUS:CONFIRMED", "TRANSP:OPAQUE", "END:VEVENT"]

    lines.append("END:VCALENDAR")
    return "\r\n".join(_fold(line) for line in lines) + "\r\n"


# ── Import: parse a foreign iCal feed ───────────────────
_DT_DATE_RE = re.compile(r"^(\d{4})(\d{2})(\d{2})$")
_DT_DTTM_RE = re.compile(r"^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z?$")


def _parse_dt_value(value: str) -> date:
    """Extract a ``date`` from an iCal ``DTSTART``/``DTEND`` value.

    Supports both ``YYYYMMDD`` (all-day) and ``YYYYMMDDTHHMMSSZ``
    (timestamp).  Any timezone is discarded; we only care about the
    calendar day.
    """
    value = value.strip()
    if (m := _DT_DATE_RE.match(value)):
        y, mo, d = (int(x) for x in m.groups())
        return date(y, mo, d)
    if (m := _DT_DTTM_RE.match(value)):
        y, mo, d, *_ = (int(x) for x in m.groups())
        return date(y, mo, d)
    raise ValueError(f"Unrecognised DTSTART/DTEND format: {value!r}")


def _strip_params(prop: str) -> tuple[str, str]:
    """Split ``DTSTART;VALUE=DATE:20260101`` → (``DTSTART``, ``20260101``)."""
    if ":" not in prop:
        return prop.upper(), ""
    head, _, value = prop.partition(":")
    name = head.split(";", 1)[0].upper()
    return name, value


def parse_feed(text: str) -> list[ICalEvent]:
    """Return every ``VEVENT`` in *text* as an :class:`ICalEvent`.

    Malformed events are skipped rather than raising – we don't want a
    single bad entry to blow away a whole sync.
    """
    # Normalise to \n so splitlines works on CRLF input.
    lines = _unfold(text.replace("\r\n", "\n").split("\n"))

    events: list[ICalEvent] = []
    in_event = False
    current: dict[str, str] = {}

    for line in lines:
        if not line:
            continue
        upper = line.upper()
        if upper == "BEGIN:VEVENT":
            in_event = True
            current = {}
            continue
        if upper == "END:VEVENT":
            in_event = False
            try:
                summary = _unesc(current.get("SUMMARY") or "External block")
                description = (
                    _unesc(current["DESCRIPTION"])
                    if "DESCRIPTION" in current else None
                )
                if "DTSTART" not in current or "DTEND" not in current:
                    # DTEND missing – assume single-day block.
                    if "DTSTART" in current:
                        start = _parse_dt_value(current["DTSTART"])
                        events.append(ICalEvent(
                            uid=current.get("UID") or str(uuid.uuid4()),
                            start=start, end=start,
                            summary=summary,
                            description=description,
                        ))
                    continue
                events.append(ICalEvent(
                    uid=current.get("UID") or str(uuid.uuid4()),
                    start=_parse_dt_value(current["DTSTART"]),
                    end=_parse_dt_value(current["DTEND"]),
                    summary=summary,
                    description=description,
                ))
            except Exception:   # pragma: no cover – best effort
                pass
            continue
        if not in_event:
            continue
        name, value = _strip_params(line)
        if name and name not in current:
            current[name] = value

    return events
