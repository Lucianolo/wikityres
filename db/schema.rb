# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170123182315) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "fornitores", force: :cascade do |t|
    t.string   "nome"
    t.string   "indirizzo"
    t.string   "user_name"
    t.string   "password"
    t.string   "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pneumaticos", force: :cascade do |t|
    t.string   "marca"
    t.string   "modello"
    t.string   "fornitore"
    t.string   "nome_fornitore"
    t.string   "misura"
    t.string   "raggio"
    t.string   "stagione"
    t.string   "cod_vel"
    t.float    "prezzo_netto"
    t.integer  "giacenza"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.string   "pfu"
  end

  add_index "pneumaticos", ["modello"], name: "index_pneumaticos_on_modello", unique: true, using: :btree

  create_table "searches", force: :cascade do |t|
    t.string   "misura"
    t.string   "tag"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string   "stagione"
    t.boolean  "finished"
  end

  create_table "users", force: :cascade do |t|
    t.string   "name"
    t.string   "password_digest"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

end
