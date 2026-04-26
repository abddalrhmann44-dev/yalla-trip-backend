"""add_property_negotiable_flag

Revision ID: b8cb13284b6f
Revises: 023_chat_negot_phone_otp
Create Date: 2026-04-25 22:23:14.161716
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'b8cb13284b6f'
down_revision: Union[str, None] = '023_chat_negot_phone_otp'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add the owner-controlled ``negotiable`` flag to properties.

    Defaults to ``False`` so existing listings keep their fixed-price
    behaviour until the owner explicitly opts into chat-based price
    negotiation from the property edit screen.
    """
    op.add_column(
        'properties',
        sa.Column(
            'negotiable',
            sa.Boolean(),
            server_default='false',
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column('properties', 'negotiable')
