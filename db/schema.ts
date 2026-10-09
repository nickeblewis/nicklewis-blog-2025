import { pgTable, serial, text, numeric, timestamp } from 'drizzle-orm/pg-core'

export const demo = pgTable('demo', {
	id: serial().primaryKey(),
	name: text().notNull(),
	description: text(),
	price: numeric({ precision: 10, scale: 2 }).notNull().default('0'),
	createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
	updatedAt: timestamp('updated_at', { withTimezone: true })
		.notNull()
		.defaultNow()
		.$onUpdate(() => new Date())
})
