"""Inputs for the Phase 1–2 work flows that use session identity."""

from datetime import date
from typing import Literal

from pydantic import AwareDatetime, Field, SecretStr, model_validator

from .models import InputModel, Money, PositiveId


class Registration(InputModel):
    username: str = Field(pattern=r"^[A-Za-z][A-Za-z0-9_]{2,31}$")
    full_name: str = Field(min_length=1, max_length=200)
    email: str = Field(max_length=254, pattern=r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
    password: SecretStr = Field(min_length=8, max_length=128)
    role: Literal["CLIENT", "FREELANCER", "BOTH"]
    company_name: str | None = Field(default=None, min_length=1, max_length=200)
    headline: str | None = Field(default=None, min_length=1, max_length=200)
    hourly_rate: Money | None = None

    @model_validator(mode="after")
    def required_profile(self):
        if self.role in {"CLIENT", "BOTH"} and not self.company_name:
            raise ValueError("A client requires a company name")
        if self.role in {"FREELANCER", "BOTH"} and (not self.headline or self.hourly_rate is None):
            raise ValueError("A freelancer requires a headline and hourly rate")
        return self


class ClientProfile(InputModel):
    company_name: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=10000)
    billing_address: str | None = Field(default=None, min_length=1, max_length=255)


class FreelancerProfile(InputModel):
    headline: str = Field(min_length=1, max_length=200)
    overview: str = Field(default="", max_length=10000)
    experience_level: Literal["ENTRY", "INTERMEDIATE", "EXPERT"] | None = None
    default_hourly_rate: Money
    availability: Literal["AVAILABLE", "UNAVAILABLE"]


class SkillLevel(InputModel):
    skill_id: PositiveId
    proficiency_level: int = Field(ge=1, le=5, strict=True)


class Skills(InputModel):
    skills: list[SkillLevel] = Field(max_length=100)

    @model_validator(mode="after")
    def unique(self):
        if len({skill.skill_id for skill in self.skills}) != len(self.skills):
            raise ValueError("Repeated skill")
        return self


class MilestonePlan(InputModel):
    title: str = Field(min_length=1, max_length=200)
    due_date: date
    amount: Money


class Decision(InputModel):
    status: Literal["SHORTLISTED", "REJECTED", "ACCEPTED"]
    expected_offered_amount: Money | None = None
    weekly_limit: int = Field(default=20, ge=1, le=168, strict=True)
    milestones: list[MilestonePlan] = Field(default_factory=list, max_length=50)


class TimeEntry(InputModel):
    start_at: AwareDatetime
    end_at: AwareDatetime
    description: str = Field(min_length=1, max_length=3000)

    @model_validator(mode="after")
    def chronological(self):
        if self.end_at <= self.start_at:
            raise ValueError("End must be after start")
        return self


class BillingWeek(InputModel):
    period_start: date


class Review(InputModel):
    rating: int = Field(ge=1, le=5, strict=True)
    comment: str | None = Field(default=None, min_length=1, max_length=3000)
